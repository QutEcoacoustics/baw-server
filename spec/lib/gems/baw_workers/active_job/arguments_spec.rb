# frozen_string_literal: true

describe BawWorkers::ActiveJob::Arguments do
  pause_all_jobs

  it 'is included in our application job' do
    expect(BawWorkers::Jobs::ApplicationJob.ancestors).to include(BawWorkers::ActiveJob::Arguments)
  end

  context 'when enqueuing will check perform_expects (0 args)' do
    subject(:job_class) {
      Class.new(BawWorkers::Jobs::ApplicationJob) do
        def perform
          # noop
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_uuid(self)
        end

        def name
          job_id
        end
      end
    }

    it 'will verify the arity of types provided with too many args' do
      expect {
        job_class.class_eval do
          perform_expects String, String, String, String
        end
        job_class.perform_later!
      }.to raise_error(ArgumentError, 'Arity of perform is 0 but 4 types were provided')
    end

    it 'will be happy with 0 args' do
      job_class.class_eval do
        perform_expects
      end
      job = job_class.perform_later!
      expect(job.status).to be_queued
      clear_pending_jobs
    end
  end

  context 'when enqueuing will check perform_expects' do
    subject(:job_class) {
      Class.new(BawWorkers::Jobs::ApplicationJob) do
        def perform(struct, num, str)
          # noop
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_uuid(self)
        end

        def name
          job_id
        end
      end
    }

    it 'will reject non-class args' do
      expect {
        job_class.class_eval do
          perform_expects 'mario'
        end
      }.to raise_error(ArgumentError, 'The value `mario` is not a class')
    end

    it 'will verify the arity of types provided with 0 args' do
      expect {
        job_class.class_eval do
          perform_expects
        end
        job_class.perform_later!
      }.to raise_error(ArgumentError, 'Arity of perform is 3 but 0 types were provided')
    end

    it 'will verify the arity of types provided with too many args' do
      expect {
        job_class.class_eval do
          perform_expects String, String, String, String
        end
        job_class.perform_later!
      }.to raise_error(ArgumentError, 'Arity of perform is 3 but 4 types were provided')
    end

    it 'errors on initialization if perform_expects was never set' do
      expect {
        job_class.perform_later!
      }.to raise_error(RuntimeError, 'perform_expects must be set before the job is run')
    end
  end

  context 'when initializing the job' do
    subject(:job_class) {
      Class.new(BawWorkers::Jobs::ApplicationJob) do
        perform_expects DemoStruct, Integer, String

        def perform(struct, num, str:)
          # noop
        end

        def create_job_id
          ::BawWorkers::ActiveJob::Identity::Generators.generate_uuid(self)
        end

        def name
          job_id
        end
      end
    }

    before do
      stub_const('DemoStruct', Class.new(BawWorkers::Dry::SerializedStrictStruct) do
        attribute :argument, ::BawWorkers::Dry::Types::String
        attribute :another, ::BawWorkers::Dry::Types::JSON::Time
      end)
    end

    let(:demo_param) { DemoStruct.new(argument: 'hello', another: Time.new(2099)) }

    it 'verifies arguments have the same arity (too few)' do
      expect {
        job_class.perform_later
      }.to raise_error(ArgumentError, 'Arity of perform is 3 but 0 args were provided')
    end

    it 'verifies arguments have the same arity (too many)' do
      expect {
        job_class.perform_later(1, 2, 3, 4)
      }.to raise_error(ArgumentError, 'Arity of perform is 3 but 4 args were provided')
    end

    it 'checks args are the correct type (simple)' do
      expect {
        job_class.perform_later(demo_param, 'hello', str: 'world')
      }.to raise_error(TypeError, 'Argument (`String`) for parameter `num` does not have expected type `Integer`')
    end

    it 'checks args are the correct type (complex)' do
      expect {
        job_class.perform_later('hello', 123, str: 'world')
      }.to raise_error(TypeError, 'Argument (`String`) for parameter `struct` does not have expected type `DemoStruct`')
    end

    it 'checks args are the correct type (keyword)' do
      expect {
        job_class.perform_later(demo_param, 123, str: 456)
      }.to raise_error(TypeError, 'Argument (`Integer`) for parameter `str` does not have expected type `String`')
    end
  end
end
