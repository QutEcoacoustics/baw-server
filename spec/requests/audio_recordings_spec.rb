# frozen_string_literal: true

describe '/audio_recordings' do
  create_entire_hierarchy

  context 'when shown, provides a timezone along with recorded date' do
    example 'when the timezone is present in the site' do
      site.tzinfo_tz = 'Australia/Sydney'
      site.save!

      get "/audio_recordings/#{audio_recording.id}", **api_headers(reader_token)

      expect_success
      expect(api_result).to include(data: hash_including({
        recorded_date_timezone: 'Australia/Sydney'
      }))
    end

    example 'when the timezone is nil in the site' do
      site.tzinfo_tz = nil
      site.save!

      get "/audio_recordings/#{audio_recording.id}", **api_headers(reader_token)

      expect_success
      expect(api_result).to include(data: hash_including({
        recorded_date_timezone: nil
      }))
    end
  end

  example 'returns a canonical_name' do
    site.tzinfo_tz = 'Australia/Brisbane'
    site.save!

    get "/audio_recordings/#{audio_recording.id}", **api_headers(reader_token)

    expect_success
    expect(api_data).to include(
      canonical_file_name: audio_recording.friendly_name
    )
  end

  example 'returns a canonical_name only when requested' do
    site.tzinfo_tz = 'Australia/Brisbane'
    site.save!

    body = {
      projection: { include: [:canonical_file_name] },
      filter: { id: { eq: audio_recording.id } }
    }

    post '/audio_recordings/filter', params: body, **api_with_body_headers(reader_token)

    expect_success
    expect_number_of_items(1)

    expect(api_data).to eq([{
      canonical_file_name: audio_recording.friendly_name
    }])
  end

  example 'can return only the information needed for a task like downloading when requested' do
    site.tzinfo_tz = 'Australia/Brisbane'
    site.save!

    body = {
      projection: { include: [:id, :recorded_date, :'sites.name', :site_id, :canonical_file_name] },
      filter: { id: { eq: audio_recording.id } }
    }

    post '/audio_recordings/filter', params: body, **api_with_body_headers(reader_token)

    expect_success
    expect_number_of_items(1)

    expect(api_data).to match([{
      canonical_file_name: audio_recording.friendly_name,
      id: audio_recording.id,
      site_id: audio_recording.site_id,
      'sites.name': audio_recording.site.name,
      recorded_date: an_instance_of(String)
    }])
  end

  example 'can filter by regions.id' do
    body = {
      projection: { include: [:id, :'regions.name', :'regions.id'] },
      filter: { 'regions.id': { eq: region.id } }
    }

    post '/audio_recordings/filter', params: body, **api_with_body_headers(reader_token)

    expect_success
    expect_number_of_items(region.sites.collect(&:audio_recordings).count)

    expect(api_data).to match([{
      id: audio_recording.id,
      'regions.id': audio_recording.site.region.id,
      'regions.name': audio_recording.site.region.name
    }])
  end
end
