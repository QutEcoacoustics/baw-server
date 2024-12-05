# frozen_string_literal: true

require 'swagger_helper'

describe 'analysis jobs', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization
  for_model AnalysisJob
  which_has_schema ref(:analysis_job)

  path '/analysis_jobs/filter' do
    post('filter analysis_job') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end
  end

  path '/analysis_jobs' do
    get('list analysis_jobs') do
      response(200, 'successful') do
        schema_for_many
        run_test! do
          expect_at_least_one_item
        end
      end
    end

    post('create analysis_job') do
      ignore_pending_jobs
      model_sent_as_parameter_in_body
      response(201, 'successful') do
        schema_for_single
        send_model do
          {
            analysis_job: {
              name: 'test job',
              description: 'test job **description**',
              ongoing: true,
              project_id: nil,
              system_job: true,
              scripts: [{ script_id: script.id }],
              filter: {}
            }
          }
        end
        run_test!
      end
    end
  end

  path '/analysis_jobs/new' do
    get('new analysis_job') do
      response(200, 'successful') do
        run_test!
      end
    end
  end

  path '/analysis_jobs/{id}' do
    with_id_route_parameter
    let(:id) { analysis_job.id }

    before do
      # can only delete an analysis job if it is suspended or completed
      analysis_job.update_column(:overall_status, :completed)
    end

    get('show analysis_job') do
      response(200, 'successful') do
        schema_for_single
        run_test! do
          expect_id_matches(analysis_job)
        end
      end
    end

    patch('update analysis_job') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        # only a subset of the writable properties can be updated
        auto_send_model subset: [:name, :description]
        run_test! do
          expect_id_matches(analysis_job)
        end
      end
    end

    put('update analysis_job') do
      model_sent_as_parameter_in_body
      response(200, 'successful') do
        schema_for_single
        # only a subset of the writable properties can be updated
        auto_send_model subset: [:name, :description]
        run_test! do
          expect_id_matches(analysis_job)
        end
      end
    end

    delete('delete analysis_job') do
      response(204, 'successful') do
        schema nil
        run_test! do
          expect_empty_body
        end
      end
    end
  end

  [
    :retry,
    :suspend,
    :resume,
    :amend
  ].each do |action|
    path "/analysis_jobs/{id}/#{action}" do
      with_id_route_parameter
      ignore_pending_jobs

      let(:id) { analysis_job.id }

      before do
        # change state based on action
        case action
        when :suspend
          analysis_job.update_column(:overall_status, :processing)
        when :resume
          analysis_job.update_column(:overall_status, :suspended)
        when :retry
          analysis_job.update_column(:overall_status, :completed)
          analysis_job.save!
          # mark one item to be failed so we can retry the job
          analysis_jobs_item.result_failed!
        when :amend
          analysis_job.update_column(:overall_status, :completed)
          analysis_job.ongoing = true
          analysis_job.save!
        end
      end

      post("#{action} analysis_job") do
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
