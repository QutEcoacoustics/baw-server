# frozen_string_literal: true

require_relative 'harvest_spec_common'

describe 'Harvesting a batch of files' do
  include HarvestSpecCommon

  extend WebServerHelper::ExampleGroup

  describe 'errors' do
    render_error_responses

    it 'cannot create a new harvest in any state' do
      body = {
        harvest: {
          streaming: false,
          status: :uploading
        }
      }

      post "/projects/#{project.id}/harvests", params: body, **api_with_body_headers(owner_token)

      expect_error(
        :unprocessable_entity,
        'The request could not be understood: found unpermitted parameter: :status'
      )
    end

    # execute the following specs in order without resetting state between them
    stepwise 'cannot transition into an error state' do
      step 'can be created' do
        create_harvest
        expect(harvest).to be_uploading
      end

      [:new_harvest, :metadata_review, :processing, :review].each do |status|
        step "cannot transition from uploading->#{status}" do
          transition_harvest(status)
          expect_transition_error(status)
        end
      end

      step 'can transition to :metadata_extraction' do
        transition_harvest(:metadata_extraction)
        expect_success
        expect(harvest).to be_metadata_extraction
      end

      [:new_harvest, :uploading, :metadata_review, :processing, :review].each do |status|
        step "the client cannot transition from metadata_extraction->#{status}" do
          transition_harvest(status)
          expect_transition_not_allowed(status)
        end
      end

      step 'can transition to :metadata_review when a client fetches the record' do
        get_harvest
        expect(harvest).to be_metadata_review
      end

      [:new_harvest, :metadata_extraction, :review].each do |status|
        step "cannot transition from metadata_review->#{status}" do
          transition_harvest(status)
          expect_transition_error(status)
        end
      end

      step 'can transition to :processing' do
        transition_harvest(:processing)
        expect_success
        expect(harvest).to be_processing
      end

      [:new_harvest, :uploading, :metadata_review, :processing, :review].each do |status|
        step "the client cannot transition from processing->#{status}" do
          transition_harvest(status)
          expect_transition_not_allowed(status)
        end
      end

      step 'can transition to :review when a client fetches the record' do
        get_harvest
        expect(harvest).to be_review
      end
    end
  end
end
