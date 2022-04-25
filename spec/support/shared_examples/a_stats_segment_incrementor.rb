# frozen_string_literal: true

require 'async/barrier'

RSpec.shared_examples 'a stats segment incrementor' do |options|
  let(:model) { options[:model] }
  let(:increment) { (options[:increment]) }
  let(:duration_key) { options[:duration_key] }
  let(:count_key) { options[:count_key] }

  context 'when dealing with multiple connections', clean_by_truncation: true do
    it 'works' do
      # I have no idea why but a concurrency of 3 (not 4 or 5) triggers the bug we're trying to reproduce here
      # Repeating this process seems to make failure more reliable
      # 9 is one less than connection pool limit
      (1..20).each do |super_index|
        model.delete_all

        Sync do |_task|
          barrier = Async::Barrier.new
          condition = Async::Condition.new
          #  ActiveRecord::StatementInvalid:
          #   PG::ExclusionViolation: ERROR:  conflicting key value violates exclusion constraint "constraint_baw_audio_recording_statistics_non_overlapping"
          numbers = super_index.times

          numbers.each do |index|
            logger.info('creating task', index:, super_index:)

            barrier.async(annotation: "upsert #{index}") do |_child|
              t = Thread.new {
                logger.info('running child', index:, super_index:)
                ActiveRecord::Base.connection_pool.with_connection do
                  instance_exec(index, &increment)
                end
              }

              logger.info('child waiting', index:, super_index:)
              condition.wait

              t.join
            end
          end

          condition.signal # punch it
          barrier.wait
        end
      end

      aggregate_failures do
        expect(model.count).to eq 1
        actual = model.first
        expect(actual.send(count_key)).to eq 20
        # the sum of the numbers 1..20
        expect(actual.send(duration_key)).to eq 1.9e2
      end
    end
  end
end
