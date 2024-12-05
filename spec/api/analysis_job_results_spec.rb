# frozen_string_literal: true

require 'swagger_helper'

describe 'analysis jobs results' do
  create_entire_hierarchy

  before do
    create_analysis_result_file(analysis_jobs_item, Pathname('Test1/Test2/test-CASE.csv'), content: 'hello')
    link_analysis_result_file(analysis_jobs_item, Pathname('archive.zip'), target: Fixtures.zip_fixture)
  end

  with_authorization
  which_has_schema FileSystems::Schema.schema(additional_data_props: {
    analysis_job_id: Api::Schema.id,
    analysis_jobs_item_ids: Api::Schema.ids
  })

  let(:skip_automatic_description) { true }
  let(:audio_recording_id) { analysis_jobs_item.audio_recording.id }
  let(:analysis_job_id) { analysis_job.id }
  let(:script_id) { analysis_jobs_item.script.id }

  with_route_parameter :analysis_job_id
  with_route_parameter :audio_recording_id
  with_route_parameter :script_id

  path '/analysis_jobs/{analysis_job_id}/results/{audio_recording_id}/{script_id}' do
    get('show analysis result directory listing') do
      produces 'application/json'
      response(200, 'successful') do
        schema_for_single

        run_test! do
          expect(api_data).to match(a_hash_including(
            path: "/analysis_jobs/#{analysis_job_id}/results/#{audio_recording_id}/#{script_id}",
            name: an_instance_of(String)
          ))
        end
      end
    end
  end

  describe 'using the latest token' do
    let(:script_id) { Script.where(id: script.id).pick(Script.analysis_identifier_and_latest_version_arel) }

    path '/analysis_jobs/{analysis_job_id}/results/{audio_recording_id}/{script_id}' do
      get('you can use the latest token to get analysis result directory listing for the latest version of a script') do
        produces 'application/json'
        response(200, 'successful') do
          schema_for_single

          run_test! do
            expect(api_data).to match(a_hash_including(
              path: "/analysis_jobs/#{analysis_job_id}/results/#{audio_recording_id}/#{script_id}",
              name: an_instance_of(String)
            ))
          end
        end
      end
    end
  end

  path '/analysis_jobs/{analysis_job_id}/results/{audio_recording_id}/{script_id}/Test1/Test2/test-CASE.csv' do
    get('download a file') do
      produces 'text/csv'
      response(200, 'successful') do
        run_test! do
          expect(response.body).to eq('hello')
        end
      end
    end
  end

  path '/analysis_jobs/{analysis_job_id}/results/{audio_recording_id}/{script_id}/archive.zip' do
    get('download a container as a file') do
      consumes 'application/zip'
      produces 'application/zip'
      response(200, 'successful') do
        run_test! do
          expect(response).to be_same_file_as(Fixtures.zip_fixture)
        end
      end
    end

    get('treat a container as a directory and list the files inside') do
      produces 'application/json'
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect(api_data).to match(a_hash_including(
            path: "/analysis_jobs/#{analysis_job_id}/results/#{audio_recording_id}/#{script_id}/archive.zip",
            name: 'archive.zip'
          ))
        end
      end
    end
  end
end
