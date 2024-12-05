# frozen_string_literal: true

require 'swagger_helper'

describe 'audio_event_import_files' do
  create_entire_hierarchy
  ignore_pending_jobs
  let!(:audio_event_import) { create(:audio_event_import, creator: writer_user) }
  let(:audio_event_import_id) { audio_event_import.id }
  let!(:audio_event_import_file) {
    create(
      :audio_event_import_file,
      :with_file,
      audio_event_import_id: audio_event_import.id
    )
  }

  sends_json_and_expects_json
  with_authorization
  for_model AudioEventImport
  which_has_schema ref(:audio_event_import_file)

  path '/audio_event_imports/{audio_event_import_id}/files/filter' do
    with_route_parameter(:audio_event_import_id)
    post('filter audio_event_import_file') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/audio_event_imports/{audio_event_import_id}/files' do
    with_route_parameter(:audio_event_import_id)

    get('list audio_event_import_files') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create audio_event_import_file') do
      consumes 'multipart/form-data'
      produces 'application/json'
      parameter(
        name: :'audio_event_import_file[file]',
        in: :formData,
        description: 'file to upload',
        type: :file,
        required: true
      )
      parameter(
        name: :'audio_event_import_file[additional_tag_ids]',
        in: :formData,
        description: 'additional tags',
        schema: {
          type: :array,
          items: {
            type: :integer
          }
        },
        required: false
      )
      parameter(
        name: :commit,
        in: :formData,
        description: 'whether to commit the imported events or not',
        type: :boolean,
        required: true,
        default: false
      )

      response(201, 'successful') do
        schema(**AudioEventImportFile.create_schema)
        let(:'audio_event_import_file[file]') {
          f = temp_file(basename: 'generic_example.csv')
          f.write <<~CSV
            audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
            #{audio_recording.id},123               ,456             ,100                ,500                 ,Birb
          CSV
          with_file(f)
        }

        let(:'audio_event_import_file[additional_tag_ids]') { [tag.id] }
        let(:commit) { true }
        run_test!
      end

      response(422, 'invalid file') do
        schema(**AudioEventImportFile.create_schema)
        let(:'audio_event_import_file[file]') {
          f = temp_file(basename: 'generic_example.csv')
          f.write <<~CSV
            audio_recording_id          ,start_time_seconds,end_time_seconds,low_frequency_hertz,high_frequency_hertz,tag
            999999999,123               ,456             ,100                ,500                 ,Birb
          CSV
          with_file(f)
        }

        let(:'audio_event_import_file[additional_tag_ids]') { [tag.id] }
        let(:commit) { true }
        run_test!
      end
    end
  end

  path '/audio_event_imports/{audio_event_import_id}/files/new' do
    with_route_parameter(:audio_event_import_id)

    get('new audio_event_import_file') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/audio_event_imports/{audio_event_import_id}/files/{id}' do
    with_route_parameter(:audio_event_import_id)
    with_id_route_parameter
    let(:id) { audio_event_import_file.id }

    get('show audio_event_import_file') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(audio_event_import_file)
        end
      end
    end

    patch('update audio_event_import_file') do
      response(404, 'not found') do
        run_test! do
        end
      end
    end

    put('update audio_event_import_file') do
      response(404, 'not found') do
        run_test! do
        end
      end
    end

    delete('delete audio_event_import_file') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end
end
