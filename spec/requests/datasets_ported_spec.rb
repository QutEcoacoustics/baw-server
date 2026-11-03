# frozen_string_literal: true

# Provenance: migrated from spec/acceptance/datasets_spec.rb.

describe 'Dataset filtering (ported acceptance cases)', type: :request do
  prepare_users
  prepare_dataset

  it 'filters by name and projects requested fields with their rendered markdown companions' do
    post '/datasets/filter',
      params: {
        filter: { name: { eq: 'default' } },
        projection: { include: ['id', 'name', 'description'] }
      },
      **api_with_body_headers(reader_token)

    expect(response).to have_http_status(:ok)
    expect(api_result[:data]).to match([
      a_hash_including({
        id: default_dataset.id,
        name: default_dataset.name,
        description: default_dataset.description,
        **default_dataset.render_markdown_for_api_for(:description)
      })
    ])
  end
end
