# frozen_string_literal: true

require 'swagger_helper'

# the cms service is provided by a third party, hence its API
# varies from our common format.
describe 'cms', type: :request do
  let(:skip_automatic_description) { true }
  create_standard_cms_pages

  path '/cms' do
    get 'Retrieves the index blob (rendered HTML)' do
      tags 'CMS'
      produces 'text/html'
      response '200', 'blob retrieved' do
        run_test! do
          expect(response.content_type).to include('text/html')
          expect(response_body).to match(%r{<h1>.*</h1>})
        end
      end
    end
    get 'Retrieves the index blob (rendered JSON)' do
      tags 'CMS'
      produces 'application/json'
      response '200', 'blob retrieved' do
        schema '$ref' => '#/components/schemas/cms_blob'
        run_test! do
          expect_json_response
        end
      end
    end
  end

  path '/cms/{child_path}' do
    get 'Retrieves the a child blob (rendered HTML)' do
      tags 'CMS'
      produces 'text/html'
      parameter name: :child_path, in: :path, type: :string
      response '200', 'blob retrieved' do
        let(:child_path) { 'credits' }
        run_test! do
          expect(response.content_type).to include('text/html')
          expect(response_body).to match(%r{<h1>.*</h1>})
        end
      end
    end
    get 'Retrieves the a child blob (rendered JSON)' do
      tags 'CMS'
      produces 'application/json'
      parameter name: :child_path, in: :path, type: :string
      response '200', 'blob retrieved' do
        schema '$ref' => '#/components/schemas/cms_blob'
        let(:child_path) { 'credits' }
        run_test! do
          expect_json_response
        end
      end
    end
  end
end
