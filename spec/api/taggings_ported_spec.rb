# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/taggings_spec.rb.

require 'swagger_helper'

describe 'Tagging responses ported from acceptance', type: :request do
  create_audio_recordings_hierarchy
  prepare_tag
  let!(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user) }

  prepare_audio_events_tags

  sends_json_and_expects_json
  with_authorization
  for_model Tagging
  which_has_schema({
    type: :object,
    required: ['id', 'audio_event_id', 'tag_id', 'created_at'],
    properties: {
      id: { type: :integer, readOnly: true },
      audio_event_id: { type: :integer },
      tag_id: { type: :integer },
      created_at: { type: :string, format: 'date-time', readOnly: true }
    }
  })

  path '/audio_recordings/{audio_recording_id}/audio_events/{audio_event_id}/taggings' do
    with_route_parameter :audio_recording_id
    with_route_parameter :audio_event_id
    let(:audio_recording_id) { audio_recording.id }
    let(:audio_event_id) { audio_event.id }

    get('list taggings for an audio event') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_number_of_items(1)
          expect(api_data.first).to include(audio_event_id: audio_event.id, tag_id: tag.id)
        end
      end
    end

    post('create a tagging using an existing tag') do
      parameter name: :tagging_attributes, in: :body, schema: {
        type: :object,
        required: ['tagging'],
        properties: {
          tagging: {
            type: :object,
            required: ['tag_id'],
            properties: { tag_id: { type: :integer } }
          }
        }
      }
      let!(:existing_tag) { create(:tag, creator: admin_user) }
      send_model { { tagging: { tag_id: existing_tag.id } } }

      response(201, 'successful') do
        schema_for_single
        run_test! do
          expect(api_data).to include(audio_event_id: audio_event.id, tag_id: existing_tag.id)
          expect(Tagging.find(api_data[:id])).to have_attributes(
            audio_event_id: audio_event.id, tag_id: existing_tag.id, creator_id: admin_user.id
          )
        end
      end
    end
  end

  path '/audio_recordings/{audio_recording_id}/audio_events/{audio_event_id}/taggings/{id}' do
    with_route_parameter :audio_recording_id
    with_route_parameter :audio_event_id
    with_id_route_parameter
    let(:audio_recording_id) { audio_recording.id }
    let(:audio_event_id) { audio_event.id }
    let(:id) { tagging.id }

    get('show a tagging') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(tagging)
          expect(api_data).to include(audio_event_id: audio_event.id, tag_id: tag.id)
        end
      end
    end
  end

  path '/user_accounts/{user_id}/taggings' do
    with_route_parameter :user_id
    let(:user_id) { writer_user.id }

    get('list taggings created by a user') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end
end
