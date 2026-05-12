# frozen_string_literal: true

require 'swagger_helper'

describe 'reports', type: :request do
  create_entire_hierarchy

  sends_json_and_expects_json
  with_authorization

  let(:skip_automatic_description) { true }

  before do
    script = create(:script, creator: writer_user, provenance:)
    analysis_job = create(:analysis_job, project:, creator: writer_user, scripts: [script])

    create(
      :analysis_jobs_item,
      analysis_job:,
      script:,
      result: AnalysisJobsItem::RESULT_SUCCESS,
      audio_recording:
    )
  end

  def self.request_body_schema
    Api::Schema.filter_payload(filter: true, sorting: false, paging: false, projection: false)
  end

  path '/reports/recording_coverage' do
    post 'Gets contiguous recording coverage spans per site' do
      tags 'reports'
      consumes 'application/json'
      produces 'application/json'

      description <<~DESCRIPTION
        Returns contiguous recording coverage spans grouped by site.
        The optional `filter` parameter is applied to audio recordings.
        Results only include audio recordings the user has reader access to.
      DESCRIPTION

      parameter name: :request_body, in: :body, required: true,
        schema: request_body_schema

      response '200', 'recording coverage report retrieved' do
        schema(**Api::Schema.coverage_report)

        let(:request_body) { { filter: {} } }

        run_test! do
          expect_at_least_one_item
        end
      end

      response '200', 'filters audio recordings by site' do
        let(:request_body) do
          {
            filter: { site_id: { eq: site.id } }
          }
        end

        run_test! do
          expect_at_least_one_item
        end
      end

      response '422', 'rejects paging parameters' do
        let(:request_body) { { paging: { items: 10 } } }

        run_test! do
          expect_error(
            :unprocessable_content,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
          )
        end
      end

      response '422', 'rejects sort parameters' do
        let(:request_body) { { sort: { order_by: 'id' } } }

        run_test! do
          expect_error(
            :unprocessable_content,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
          )
        end
      end

      response '422', 'rejects projection parameters' do
        let(:request_body) { { projection: { only: [:id] } } }

        run_test! do
          expect_error(
            :unprocessable_content,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
          )
        end
      end
    end
  end

  path '/reports/analysis_coverage' do
    post 'Gets contiguous analysis coverage spans per site and result' do
      tags 'reports'
      consumes 'application/json'
      produces 'application/json'

      description <<~DESCRIPTION
        Returns contiguous analysis coverage spans grouped by site and analysis job item result.
        The optional `filter` parameter is applied to audio recordings.
        Results only include audio recordings the user has reader access to.
      DESCRIPTION

      parameter name: :request_body, in: :body, required: true,
        schema: request_body_schema

      response '200', 'analysis coverage report retrieved' do
        schema(**Api::Schema.coverage_report(include_result: true))

        let(:request_body) { { filter: {} } }

        run_test! do
          expect_at_least_one_item
        end
      end

      response '200', 'filters audio recordings by site' do
        let(:request_body) do
          {
            filter: { site_id: { eq: site.id } }
          }
        end

        run_test! do
          expect_at_least_one_item
        end
      end

      response '422', 'rejects paging parameters' do
        let(:request_body) { { paging: { items: 10 } } }

        run_test! do
          expect_error(
            :unprocessable_content,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
          )
        end
      end

      response '422', 'rejects sort parameters' do
        let(:request_body) { { sort: { order_by: 'id' } } }

        run_test! do
          expect_error(
            :unprocessable_content,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
          )
        end
      end

      response '422', 'rejects projection parameters' do
        let(:request_body) { { projection: { only: [:id] } } }

        run_test! do
          expect_error(
            :unprocessable_content,
            'The request could not be understood: Paging, sorting, and projection parameters are not allowed in group by or reporting requests.'
          )
        end
      end
    end
  end
end
