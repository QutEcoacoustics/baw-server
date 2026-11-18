# frozen_string_literal: true

# https://github.com/QutEcoacoustics/baw-server/issues/1087
describe 'Filtering AudioEvents by taggings' do
  create_audio_recordings_hierarchy

  let!(:koala) { create(:tag, creator: owner_user) }
  let!(:kookaburra) { create(:tag, creator: owner_user) }

  let!(:koala_event) { create_event(koala) }
  let!(:both_event) { create_event(koala, kookaburra) }
  let!(:kookaburra_event) { create_event(kookaburra) }
  let!(:untagged_event) { create_event }

  def create_event(*tags)
    create(:audio_event, audio_recording:, creator: owner_user).tap do |event|
      tags.each { |tag| create(:tagging, audio_event: event, tag:, creator: owner_user) }
    end
  end

  def expect_filtered_events(filter, *expected_events)
    post '/audio_events/filter?disable_paging=true',
      params: { filter:, projection: { only: [:id] } },
      **api_with_body_headers(reader_token)

    expect_success
    expect(api_data.pluck(:id)).to match_array(expected_events.map(&:id))
  end

  [:audio_events_tags, :taggings].each do |name|
    it "can use the `#{name}` name for a scope" do
      expect_filtered_events({ name => { any: { tag_id: { eq: koala.id } } } }, koala_event, both_event)
    end

    it "can use the `#{name}` name for an associated field" do
      expect_filtered_events({ "#{name}.tag_id": { eq: kookaburra.id } }, both_event, kookaburra_event)
    end
  end

  it 'can use the taggings name with the none operator' do
    expect_filtered_events(
      { taggings: { none: { tag_id: { eq: koala.id } } } },
      kookaburra_event, untagged_event
    )
  end

  it 'can use the taggings name with the all operator' do
    expect_filtered_events(
      { taggings: { all: { tag_id: { eq: koala.id } } } },
      koala_event, untagged_event
    )
  end

  it 'still filters the taggings field when the value is not a scope' do
    expect_filtered_events({ taggings: { eq: nil } }, untagged_event)
  end
end
