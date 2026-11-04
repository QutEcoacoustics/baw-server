# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/responses_spec.rb.

describe 'Responses (ported)', type: :request do
  create_entire_hierarchy

  it 'allows the responder to filter serialized data and project only the data' do
    post '/responses/filter',
      params: { filter: { data: { starts_with: '{' } }, projection: { include: [:data] } },
      headers: { 'HTTP_AUTHORIZATION' => reader_token }, as: :json

    expect(response).to have_http_status(:ok)
    expect(api_result[:data]).to contain_exactly({ data: user_response.data }, { data: default_user_response.data })
    expect_has_projection(only: ['data'])
  end

  # Empty-list contents are asserted by the permissions spec; these preserve the
  # legacy default sorting assertions for non-responders.
  [
    [:owner, :get, '/responses'],
    [:writer, :get, '/responses'],
    [:owner, :post, '/responses/filter'],
    [:writer, :post, '/responses/filter'],
    [:no_access, :post, '/responses/filter']
  ].each do |user, verb, path|
    it "sorts #{verb.upcase} #{path} by created_at descending for a non-responder (#{user})" do
      process verb, path, headers: { 'HTTP_AUTHORIZATION' => send(:"#{user}_token") }, as: :json

      expect(response).to have_http_status(:ok)
      expect_has_sorting(order_by: 'created_at', direction: 'desc')
    end
  end
end
