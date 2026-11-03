# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/questions_spec.rb.

describe 'Question filter projection (ported)', type: :request do
  create_entire_hierarchy

  it 'allows a reader to filter by text and project only the text' do
    post '/questions/filter',
      params: { filter: { text: { starts_with: 'test question' } }, projection: { include: [:text] } },
      headers: { 'HTTP_AUTHORIZATION' => reader_token }, as: :json

    expect(response).to have_http_status(:ok)
    expect(api_result[:data]).to contain_exactly({ text: question.text }, { text: default_question.text })
    expect_has_projection(only: ['text'])
  end
end
