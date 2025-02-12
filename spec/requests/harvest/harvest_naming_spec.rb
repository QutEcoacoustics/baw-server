# frozen_string_literal: true

require_relative 'harvest_spec_common'

describe 'Harvesting files', :clean_by_truncation do
  include HarvestSpecCommon
  render_error_responses
  pause_all_jobs

  context 'when changing the name' do
    before do
      Timecop.freeze
    end

    after do
      Timecop.return
    end

    let(:default_name) { "#{Time.zone.now.strftime('%B')} #{Time.zone.now.day.ordinalize} Upload" }

    context 'when streaming' do
      it 'can set a name on create' do
        create_harvest(streaming: true, name: 'Woo hoo!')
        expect_success

        expect(harvest.name).to eq 'Woo hoo!'
      end

      it 'if null will use a default name on create' do
        create_harvest(streaming: true)
        expect_success

        expect(harvest.name).to eq default_name
      end

      it '(:uploading) can revert to the default name' do
        create_harvest(streaming: true, name: 'I got my head checked')
        expect_success

        expect(harvest).to be_uploading

        rename_harvest(nil)
        expect_success

        expect(harvest.name).to eq default_name
      end

      it '(:uploading) can update the name' do
        create_harvest(streaming: true)
        expect_success

        expect(harvest).to be_uploading

        rename_harvest('By a jumbo jet')
        expect_success

        expect(harvest.name).to eq 'By a jumbo jet'
      end

      it '(:complete) can revert to the default name' do
        create_harvest(streaming: true, name: 'It wasn\'t easy')
        expect_success
        transition_harvest(:complete)
        expect(harvest).to be_complete

        rename_harvest(nil)
        expect_success

        expect(harvest.name).to eq default_name
        clear_pending_jobs
      end

      it '(:complete) can update the name' do
        create_harvest(streaming: true)
        expect_success
        transition_harvest(:complete)
        expect(harvest).to be_complete

        rename_harvest('But nothing i-is, no')
        expect_success

        expect(harvest.name).to eq 'But nothing i-is, no'
        clear_pending_jobs
      end
    end

    context 'when batch uploading' do
      it 'can set a name on create' do
        create_harvest(streaming: false, name: 'Woo hoo!')
        expect_success

        expect(harvest.name).to eq 'Woo hoo!'
      end

      it 'if null will use a default name on create' do
        create_harvest(streaming: false)
        expect_success

        expect(harvest.name).to eq default_name
      end

      stepwise 'setting names at various stages' do
        step 'create' do
          create_harvest(streaming: false)
          expect_success
        end

        step ':uploading can set a name' do
          expect(harvest).to be_uploading
          rename_harvest('When I feel heavy metal')
          expect_success
          get_harvest
          expect(harvest.name).to eq 'When I feel heavy metal'
        end

        step ':uploading can unset a name' do
          rename_harvest(nil)
          expect_success
          get_harvest
          expect(harvest.name).to eq default_name
        end

        step 'cannot set when :scanning' do
          transition_harvest(:scanning)
          expect_success
          expect(harvest).to be_scanning

          rename_harvest('And I\'m pins and I\'m needles')
          expect_transition_not_allowed
        end

        step 'transition to :metadata_extraction' do
          expect_enqueued_jobs(1, of_class: BawWorkers::Jobs::Harvest::ScanJob)
          perform_jobs(count: 1)
          expect_jobs_to_be(completed: 1, of_class: BawWorkers::Jobs::Harvest::ScanJob)
        end

        step 'cannot set when :metadata_extraction' do
          harvest.reload
          expect(harvest).to be_metadata_extraction

          rename_harvest('Well I lie and I\'m easy')
          expect_transition_not_allowed
        end

        step ':metadata_review can set a name' do
          get_harvest
          expect(harvest).to be_metadata_review
          rename_harvest('All of the time but I\'m never sure why I need you')
          expect_success
          get_harvest
          expect(harvest.name).to eq 'All of the time but I\'m never sure why I need you'
        end

        step ':metadata_review can unset a name' do
          rename_harvest(nil)
          expect_success
          get_harvest
          expect(harvest.name).to eq default_name
        end

        step 'cannot set when :processing' do
          transition_harvest(:processing)
          expect_success
          expect(harvest).to be_processing

          rename_harvest('Pleased to meet you')
          expect_transition_not_allowed
        end

        step ':completed can set a name' do
          get_harvest
          expect(harvest).to be_complete
          rename_harvest('I got my head down')
          expect_success
          get_harvest
          expect(harvest.name).to eq 'I got my head down'
        end

        step ':completed can unset a name' do
          rename_harvest(nil)
          expect_success
          get_harvest
          expect(harvest.name).to eq default_name
        end

        step 'done' do
          # Woo hoo!
          clear_pending_jobs
        end
      end
    end
  end
end
