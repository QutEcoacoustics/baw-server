# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/tags_spec.rb.

require 'swagger_helper'

describe 'Tag responses ported from acceptance', type: :request do
  create_audio_recordings_hierarchy
  prepare_tag
  let!(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user) }

  prepare_audio_events_tags

  sends_json_and_expects_json
  with_authorization
  for_model Tag
  which_has_schema({
    type: :object,
    required: ['id', 'text', 'is_taxonomic', 'type_of_tag', 'retired', 'notes', 'creator_id', 'updater_id',
               'created_at', 'updated_at'],
    properties: {
      id: { type: :integer },
      text: { type: :string },
      is_taxonomic: { type: :boolean },
      type_of_tag: { type: :string, enum: Tag::AVAILABLE_TYPE_OF_TAGS },
      retired: { type: :boolean },
      notes: { type: :object, nullable: true },
      creator_id: { type: :integer },
      updater_id: { type: :integer, nullable: true },
      created_at: { type: :string, format: 'date-time' },
      updated_at: { type: :string, format: 'date-time' }
    }
  })

  path '/audio_recordings/{audio_recording_id}/audio_events/{audio_event_id}/tags' do
    with_route_parameter :audio_recording_id
    with_route_parameter :audio_event_id
    let(:audio_recording_id) { audio_recording.id }
    let(:audio_event_id) { audio_event.id }

    get('list tags for an audio event') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/tags' do
    get('list tags with an audio event query parameter') do
      parameter name: :audio_event_id, in: :query, type: :integer, required: false
      parameter name: :audio_recording_id, in: :query, type: :integer, required: false
      let(:audio_event_id) { audio_event.id }
      let(:audio_recording_id) { audio_recording.id }

      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/tags/new' do
    which_has_schema({
      type: :object,
      required: ['text', 'is_taxonomic', 'type_of_tag', 'retired', 'notes'],
      properties: {
        text: { type: :string, nullable: true },
        is_taxonomic: { type: :boolean },
        type_of_tag: { type: :string, nullable: true },
        retired: { type: :boolean },
        notes: { type: :object, nullable: true }
      }
    })

    get('new tag template') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect(api_data).to include(
            text: nil, is_taxonomic: false, type_of_tag: nil, retired: false, notes: nil
          )
        end
      end
    end
  end
end
