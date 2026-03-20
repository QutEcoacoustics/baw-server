# frozen_string_literal: true

describe 'reports/tag_accumulation' do
  create_audio_recordings_hierarchy

  it 'can return a result' do
    body = { options: { bucket_size: 'day' }, filter: {} }

    # it's not clear you are missing bucket_size from the error message
    # body = { options: {}, filter: {} }
    #  {"meta":{"status":422,"message":"Unprocessable Content","error":{"details":"The request could not be understood: param is missing or the value is empty or invalid: options"}},"data":null}
    # debugger
    # -- make some tags
    # build_list(:tag, 3, creator: writer_user)
    # the key to the setup is multiple recordings and events but the same tags across them.

    tag_keys = [:koala, :whip_bird, :riflebird]
    tags = tag_keys.index_with { |tag_name| create(:tag, text: tag_name, creator: writer_user) }

    # create 2 events + taggings on the default audio_recording from hierarchy
    event_a_one = create(:audio_event, audio_recording:, creator: writer_user)
    create(:tagging, audio_event: event_a_one, tag: tags[:koala], creator: writer_user)

    event_a_two = create(:audio_event, audio_recording:, creator: writer_user)
    create(:tagging, audio_event: event_a_two, tag: tags[:whip_bird], creator: writer_user)

    # -- get dates to make next recordings on
    # -- with a 1 day gap between them, to confirm the output includes empty buckets
    second_recording_date = audio_recording.recorded_date + 1.day
    third_recording_date = audio_recording.recorded_date + 3.days

    # -- audio recording 2
    ar_2 = create(:audio_recording, site: site, creator: writer_user, recorded_date: second_recording_date)

    event_b_one = create(:audio_event, audio_recording: ar_2, creator: writer_user)
    create(:tagging, audio_event: event_b_one, tag: tags[:koala], creator: writer_user)

    # -- audio recording 3
    ar_3 = create(:audio_recording, site: site, creator: writer_user, recorded_date: third_recording_date)

    event_c_one = create(:audio_event, audio_recording: ar_3, creator: writer_user)
    create(:tagging, audio_event: event_c_one, tag: tags[:riflebird], creator: writer_user)

    event_c_two = create(:audio_event, audio_recording: ar_3, creator: writer_user)
    create(:tagging, audio_event: event_c_two, tag: tags[:riflebird], creator: writer_user)

    post '/reports/tag_accumulation', params: body, **api_headers(writer_token)

    expect_success
    expected = [a_hash_including(bucket: match(/#{audio_recording.recorded_date.to_date.to_fs(:inspect)}/), cumulative_unique_tag_count: 2),
                a_hash_including(bucket: match(/2000/), cumulative_unique_tag_count: 2),
                a_hash_including(bucket: match(/2000/), cumulative_unique_tag_count: 2),
                a_hash_including(bucket: match(/2000/), cumulative_unique_tag_count: 3)]

    expect(api_data).to match expected
  end

  # first, lets make three recordings/events on three days, use a day bucket, and just get total tag count per bucket
  # audio_recording.start_time  + 1 day, + 2 days, something like that?

  # later on:
  # create three audio recordings,
  # day 1, day 2, day 3
  # create events on each day, with tags
  # day 1: {tag 1, tag 2}  -- expect tag count = 2, cumulative tag count = 2
  # day 2: {tag 1}         -- expect tag count = 1, cumulative tag count = 2
  # day 3: {tag 2, tag 3}  -- expect tag count = 2, cumulative tag count = 3
  #
  # it can return the result shape we expect - three buckets
end
