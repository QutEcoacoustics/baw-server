# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/studies_spec.rb.

describe 'Study filter projection (ported)', type: :request do
  create_entire_hierarchy

  it 'allows a reader to filter by name and project only the name' do
    post '/studies/filter',
      params: { filter: { name: { starts_with: 'test study' } }, projection: { include: [:name] } },
      headers: { 'HTTP_AUTHORIZATION' => reader_token }, as: :json

    expect(response).to have_http_status(:ok)
    expect(api_result[:data]).to contain_exactly({ name: study.name }, { name: default_study.name })
    expect_has_projection(only: ['name'])
  end
end
