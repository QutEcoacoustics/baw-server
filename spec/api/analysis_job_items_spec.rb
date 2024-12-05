# frozen_string_literal: true

require 'swagger_helper'

describe 'analysis jobs items', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model AnalysisJobsItem
  which_has_schema ref(:analysis_jobs_item)

  with_route_parameter :analysis_job_id
  let(:analysis_job_id) { analysis_job.id }

  path '/analysis_jobs/{analysis_job_id}/items/filter' do
    post('filter analysis_jobs_item') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/analysis_jobs/{analysis_job_id}/items' do
    get('list analysis_jobs') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    # not exposed in our API
    post('create analysis_jobs_item') do
      model_sent_as_parameter_in_body
      response(404, 'not found') do
        auto_send_model
        run_test!
      end
    end
  end

  path '/analysis_jobs/{analysis_job_id}/items/new' do
    # not exposed in our API
    get('new analysis_jobs_item') do
      response(404, 'not found') do
        run_test!
      end
    end
  end

  path '/analysis_jobs/{analysis_job_id}/items/{id}' do
    with_id_route_parameter
    with_route_parameter :analysis_job_id

    let(:id) { analysis_jobs_item.id }

    before do
      analysis_jobs_item.update_column(:status, :queued)
    end

    get('show analysis_jobs_item') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(analysis_jobs_item)
        end
      end
    end

    patch('update analysis_jobs_item') do
      response(404, 'not found') do
        run_test!
      end
    end

    put('update analysis_jobs_item') do
      response(404, 'not found') do
        run_test!
      end
    end

    delete('delete analysis_jobs_item') do
      response(404, 'not found') do
        schema nil
        run_test!
      end
    end
  end

  [
    'finish',
    'working'
  ].each do |action|
    path "/analysis_jobs/{analysis_job_id}/items/{id}/#{action}" do
      with_id_route_parameter
      with_route_parameter :analysis_job_id

      let(:id) { analysis_jobs_item.id }

      before do
        analysis_jobs_item.update_column(:status, :queued)
      end

      post("#{action} analysis_jobs_item") do
        response(204, 'successful') do
          schema nil
          run_test! do
            expect_empty_body
          end
        end
      end
    end
  end
end
