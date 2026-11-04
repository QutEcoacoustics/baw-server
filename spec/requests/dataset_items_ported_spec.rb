# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/dataset_items_spec.rb.

describe 'Dataset item filtering (ported acceptance cases)', type: :request do
  create_audio_recordings_hierarchy
  prepare_dataset
  prepare_dataset_item
  create_no_access_hierarchy

  let!(:another_dataset) { create(:dataset, creator: owner_user) }
  let!(:another_dataset_item) {
    create(:dataset_item, creator: admin_user, dataset: another_dataset, audio_recording:)
  }
  let!(:ordered_items) {
    [[3, 4, 1], [1, 2, 5], [5, 6, 2], [8, 80, 4]].map do |start_time, end_time, order|
      create(:dataset_item, creator: admin_user, dataset:, audio_recording:,
        start_time_seconds: start_time, end_time_seconds: end_time, order:)
    end
  }

  it 'indexes only the requested dataset in ascending order' do
    get "/datasets/#{dataset.id}/items", **api_headers(reader_token)

    expect(response).to have_http_status(:ok)
    expected = [dataset_item, *ordered_items].sort_by { |item| [item.order, item.id] }
    expect(api_result[:data].pluck(:id)).to eq(expected.map(&:id))
    expect(api_result.dig(:meta, :sorting)).to include(order_by: 'order', direction: 'asc')
  end

  it 'filters start times across datasets, projects fields, and excludes inaccessible recordings' do
    post '/dataset_items/filter',
      params: {
        filter: { start_time_seconds: { in: ['11', '7', '100', '4'] } },
        projection: { include: ['id', 'start_time_seconds', 'audio_recording_id', 'creator_id'] }
      },
      **api_with_body_headers(reader_token)

    expect(response).to have_http_status(:ok)
    expected = [dataset_item, default_dataset_item, another_dataset_item]
    expect(api_result[:data].pluck(:id)).to match_array(expected.map(&:id))
    api_result[:data].each do |item|
      expect(item.keys).to contain_exactly(:id, :start_time_seconds, :audio_recording_id, :creator_id)
      expect(item[:start_time_seconds]).to eq(11.0)
    end
  end

  it 'returns an empty result when no start times match' do
    post '/dataset_items/filter',
      params: {
        filter: { start_time_seconds: { in: ['7', '100', '4'] } },
        projection: { include: ['id', 'start_time_seconds', 'audio_recording_id', 'creator_id'] }
      },
      **api_with_body_headers(reader_token)

    expect(response).to have_http_status(:ok)
    expect(api_result[:data]).to eq([])
  end

  # The existing next_for_me ordering/paging examples are pending, not active coverage.
  # Port only the active acceptance access/scoping case; do not revive the pending algorithm tests.
  context 'with a public project, next_for_me' do
    create_anon_hierarchy

    it 'allows anonymous access to public recordings without leaking private or other-dataset items' do
      create(:dataset_item, creator: admin_user, dataset: another_dataset, audio_recording: audio_recording_anon)

      get "/datasets/#{dataset.id}/dataset_items/next_for_me", **api_headers(nil)

      expect(response).to have_http_status(:ok)
      expect(api_result[:data].pluck(:id)).to eq([dataset_item_anon.id])
      expect(api_result.dig(:meta, :paging, :total)).to eq(1)
    end
  end
end
