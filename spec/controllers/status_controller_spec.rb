# frozen_string_literal: true

describe StatusController, type: :controller do
  describe '#batch_analysis_connected?' do
    subject(:connected) { controller.send(:batch_analysis_connected?) }

    let(:communicator) { BawWorkers::Config.redis_communicator }
    let(:batch_analysis) { BawWorkers::Config.batch_analysis }
    let(:key) { 'status:batch_analysis:connected' }
    let(:pending) { { 'status' => 'pending', 'token' => SecureRandom.uuid } }

    [true, false].each do |value|
      it "returns a cached #{value} without checking the remote connection" do
        communicator.set(key, value, expire_seconds: 60)
        expect(batch_analysis).not_to receive(:remote_connected?)

        expect(connected).to eq(value)
      end

      it "caches a #{value} result for 60 seconds" do
        expect(batch_analysis).to receive(:remote_connected?).once do
          expect(communicator.get(key)).to include('status' => 'pending', 'token' => a_kind_of(String))
          expect(communicator.ttl(key)).to be_between(1, 60)
          value
        end

        expect(connected).to eq(value)
        expect(controller.send(:batch_analysis_connected?)).to eq(value)
        expect(communicator.get(key)).to eq(value)
        expect(communicator.ttl(key)).to be_between(1, 60)
      end
    end

    it 'waits for an in-progress check without making another remote connection' do
      communicator.set(key, pending, expire_seconds: 60)
      expect(batch_analysis).not_to receive(:remote_connected?)
      expect(controller).to receive(:sleep).with(0.1) do
        communicator.set(key, true, expire_seconds: 60)
      end

      expect(connected).to be true
    end

    it 'uses the result of another request that wins the atomic cache claim' do
      expect(communicator).to receive(:get).with(key).and_return(nil, false)
      expect(communicator.redis).to receive(:set)
        .with(communicator.add_namespace(key), a_kind_of(String), ex: 60, nx: true)
        .and_return(nil)
      allow(controller).to receive(:sleep)
      expect(batch_analysis).not_to receive(:remote_connected?)

      expect(connected).to be false
    end

    it 'times out rather than waiting indefinitely for a pending check' do
      communicator.set(key, pending, expire_seconds: 60)
      expect(batch_analysis).not_to receive(:remote_connected?)
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(0, 2)

      expect { connected }.to raise_error(RuntimeError, 'timeout')
      expect(communicator.get(key)).to eq(pending)
    end

    [true, :pending].each do |value|
      it "checks again after a cached #{value} expires" do
        communicator.set(key, value == :pending ? pending : value, expire_seconds: 60)
        communicator.redis.expire(communicator.add_namespace(key), 0)
        expect(batch_analysis).to receive(:remote_connected?).once.and_return(false)

        expect(connected).to be false
        expect(communicator.get(key)).to be false
        expect(communicator.ttl(key)).to be_between(1, 60)
      end
    end

    it 'preserves connection errors and leaves an expiring pending key' do
      expect(batch_analysis).to receive(:remote_connected?)
        .and_raise(PBS::Errors::TransportError, 'failed to test_connection')

      expect { connected }.to raise_error(PBS::Errors::TransportError, 'failed to test_connection')
      expect(communicator.get(key)).to include('status' => 'pending')
      expect(communicator.ttl(key)).to be_between(1, 60)
    end

    it 'does not overwrite a newer pending check after its lease expires' do
      expect(batch_analysis).to receive(:remote_connected?) do
        communicator.set(key, pending, expire_seconds: 60)
        true
      end

      expect(connected).to be true
      expect(communicator.get(key)).to eq(pending)
    end

    it 'does not overwrite a newer result after its lease expires' do
      expect(batch_analysis).to receive(:remote_connected?) do
        communicator.set(key, false, expire_seconds: 60)
        true
      end

      expect(connected).to be true
      expect(communicator.get(key)).to be false
    end
  end
end
