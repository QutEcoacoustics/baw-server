# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/saved_searches_spec.rb.

describe 'Saved search behaviour (ported)', type: :request do
  create_audio_recordings_hierarchy
  prepare_saved_search

  it 'compares the complete stored query as JSON and projects the requested fields' do
    query = { uuid: { eq: 'blah blah' } }
    saved_search.update!(stored_query: query)
    create(:saved_search, creator: writer_user, projects: [project],
      stored_query: { uuid: { eq: 'different' } })
    hidden_project = create(:project, creator: no_access_user)
    create(:saved_search, creator: no_access_user, projects: [hidden_project], stored_query: query)

    post '/saved_searches/filter', params: {
      filter: { stored_query: { eq: query } },
      projection: { include: ['id', 'name', 'stored_query'] }
    }, **api_with_body_headers(reader_token)

    expect_success
    expect(api_data).to match([
      a_hash_including(id: saved_search.id, name: saved_search.name, stored_query: query)
    ])
    expect(api_result[:meta][:filter]).to include(stored_query: { eq: query })
    expect_has_projection(only: ['id', 'name', 'stored_query'])
    expect(api_data.first).not_to have_key(:description)
  end

  it 'includes the stored query and analysis job ids when shown' do
    get "/saved_searches/#{saved_search.id}", **api_headers(admin_token)

    expect_success
    expect(api_data).to include(
      id: saved_search.id,
      stored_query: saved_search.stored_query.deep_symbolize_keys,
      analysis_job_ids: []
    )
  end

  { put: :writer, patch: :reader }.each do |verb, role|
    it "reports the original #{verb.upcase} method for an unsupported update" do
      original_attributes = saved_search.attributes

      public_send(verb, "/saved_searches/#{saved_search.id}", params: {
        saved_search: {
          name: 'changed name',
          description: 'changed description',
          stored_query: { uuid: { eq: audio_recording.uuid } }
        }
      }, **api_with_body_headers(public_send(:"#{role}_token")))

      expect(response).to have_http_status(:not_found)
      expect(api_result[:meta][:error][:info]).to include(original_http_method: verb.to_s.upcase)
      expect(saved_search.reload.attributes).to match_attributes(original_attributes)
    end
  end
end
