# frozen_string_literal: true

describe 'Audio Event Reports' do
  create_entire_hierarchy

  let(:other_site) {
    create(:site, creator: writer_user, region: site.region, projects: site.projects)
  }

  let(:other_recording_different_site) {
    create(:audio_recording, creator: writer_user, site: other_site)
  }

  before do
    not_my_recording_and_site = create(:audio_recording, creator: reader_user)

    5.times do
      # 5 events from default recording and site
      create(:audio_event_with_tags, creator: writer_user, audio_recording:)
      # 5 events from other recording and site
      create(:audio_event_with_tags, creator: writer_user, audio_recording: other_recording_different_site)
      # 5 events with no access from not my recording and site
      create(:audio_event_with_tags, creator: reader_user, audio_recording: not_my_recording_and_site)
    end
    # and you expect 16 audio events with permission to view 11
    # where 6 are from site 1 and 5 are from site 2
  end

  it 'can filter' do
    filter = {
      filter: {}
    }

    post '/audio_event_reports', params: filter, **api_with_body_headers(writer_token)

    expect(api_result).to include(a_hash_including(
      site_ids: "{#{audio_recording.site.id},#{other_site.id}}",
      audio_recording_ids: "{#{audio_recording.id},#{other_recording_different_site.id}}"
    ))

    tags_array = Tagging.where(creator_id: writer_user.id).pluck(:id)
    expect(api_result[0][:tag_ids].tr('{}', '').split(',').map(&:to_i)).to match_array(tags_array)
  end
end
