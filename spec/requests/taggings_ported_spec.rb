# frozen_string_literal: true
# Provenance: migrated from spec/acceptance/taggings_spec.rb.

describe 'Tagging filtering ported from acceptance', type: :request do
  create_audio_recordings_hierarchy
  prepare_tag
  let!(:audio_event) { create(:audio_event, audio_recording:, creator: writer_user, is_reference: false) }

  prepare_audio_events_tags

  [
    { audio_event_id: { gt: 0 } },
    { 'audio_events.is_reference': { eq: false } }
  ].each do |filter|
    it "filters with #{filter} and preserves projection, sorting and pagination metadata" do
      if filter.key?(:'audio_events.is_reference')
        reference_event = create(:audio_event, audio_recording:, creator: writer_user, is_reference: true)
        create(:tagging, audio_event: reference_event, tag:, creator: writer_user)
      end

      fields = ['id', 'audio_event_id', 'tag_id', 'created_at']
      post '/taggings/filter', params: { filter:, projection: { include: fields } },
        **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(1)
      expect(api_data.first).to include(id: tagging.id, audio_event_id: audio_event.id, tag_id: tag.id)
      expect(api_data.first.keys).to match_array(fields.map(&:to_sym))
      expect_has_filter(filter)
      expect_has_projection(only: fields)
      expect_has_sorting(order_by: 'id')
      expect_has_paging(page: 1, items: 25, total: 1)
      expect(api_result.dig(:meta, :paging, :max_page)).to eq(1)

      current = URI.parse(api_result.dig(:meta, :paging, :current))
      expect(current.path).to eq('/taggings/filter')
      expect(Rack::Utils.parse_query(current.query)).to eq(
        'direction' => 'asc', 'items' => '25', 'order_by' => 'id', 'page' => '1'
      )
    end
  end

  it 'lists only taggings created by the requested user' do
    other_tag = create(:tag, creator: admin_user)
    create(:tagging, audio_event:, tag: other_tag, creator: admin_user)

    get "/user_accounts/#{writer_user.id}/taggings", **api_headers(reader_token)

    expect_success
    expect(api_data.pluck(:id)).to eq([tagging.id])
  end
end
