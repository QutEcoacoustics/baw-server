# frozen_string_literal: true

require 'swagger_helper'

describe 'exports', type: :request do
  create_audio_recordings_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model Export
  which_has_schema ref(:export)

  let!(:export) { create(:export, creator: admin_user, project:) }

  path '/exports/filter' do
    post('filter export') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/exports' do
    get('list exports') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create export') do
      pause_all_jobs
      ignore_pending_jobs
      model_sent_as_parameter_in_body

      response(201, 'successful') do
        schema(**Api::Schema.standard_single_response(Export.create_response_schema))
        send_model do
          {
            export: {
              export_type: 'camtrap_dp',
              name: 'Documented export',
              project_id: project.id,
              filter: {},
              options: {
                contributors: [{ title: 'Alice' }],
                project_capture_method: ['continuous'],
                project_sampling_design: 'systematicRandom'
              },
              obfuscate_locations: true
            }
          }
        end
        run_test! do
          expect(api_data).to include(status: 'queued', creator_id: admin_user.id, obfuscate_locations: true)
        end
      end

      response(422, 'invalid export') do
        send_model do
          {
            export: {
              export_type: 'camtrap_dp',
              name: 'Invalid export',
              project_id: project.id,
              filter: {},
              options: {}
            }
          }
        end
        run_test! do
          expect_error(:unprocessable_content, 'Record could not be saved')
        end
      end
    end
  end

  path '/exports/new' do
    get('new export') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/exports/{id}' do
    with_id_route_parameter
    let(:id) { export.id }

    get('show export') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(export)
        end
      end
    end

    delete('delete export') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end

      response(409, 'export is being generated') do
        before { export.update!(status: 'working') }

        run_test! do
          expect_error(:conflict, 'Cannot be deleted while `status` is `working`')
        end
      end
    end
  end

  path '/exports/{id}/download' do
    with_id_route_parameter
    let(:id) { export.id }

    get('download export') do
      consumes nil
      produces 'application/zip', 'application/json'
      parameter name: :token, in: :query, required: false, schema: { type: :string },
        description: 'The `token` returned when the export was created. ' \
                     'When given, the export can be downloaded without logging in. ' \
                     'When omitted, the current user must be the creator of the export.'

      response(200, 'successful') do
        let!(:export) { create(:export, :with_zip_file, creator: admin_user, project:, status: 'ready') }

        run_test! do
          expect(response.content_type).to eq('application/zip')
        end
      end

      response(503, 'export is not ready yet') do
        before { export.update!(status: 'working') }

        run_test! do
          expect_error(:service_unavailable, 'The export is not ready yet. Try again later.')
        end
      end

      response(410, 'export has expired or was purged') do
        let!(:export) { create(:export, :with_zip_file, creator: admin_user, project:, status: 'ready') }
        before { export.update!(expires_at: 1.day.ago) }

        run_test! do
          expect_error(:gone, 'The requested item is no longer available: The export has expired or was purged')
        end
      end

      response(422, 'export generation failed') do
        before { export.update!(status: 'failed', error: 'The export could not be generated') }

        run_test! do
          expect_error(:unprocessable_content, 'The request could not be understood: The export could not be generated')
        end
      end
    end
  end
end
