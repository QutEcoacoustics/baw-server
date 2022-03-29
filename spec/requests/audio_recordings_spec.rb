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
    site.tzinfo_tz = 'Australia/Sydney'
    site.save!

    get "/audio_recordings/#{audio_recording.id}", **api_headers(reader_token)

    expect_success
    expect(api_data).to include(
      canonical_file_name: audio_recording.friendly_name
    )
  end

  example 'returns a canonical_name only when requested' do
    site.tzinfo_tz = 'Australia/Sydney'
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
    site.tzinfo_tz = 'Australia/Sydney'
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

  example 'it can retrieve recent audio recordings' do
    body = {
      projection: { include: [:id, :siteId, :durationSeconds, :recordedDate, :createdAt] },
      sorting: { orderBy: 'createdAt', direction: 'desc' }
    }

    post '/audio_recordings/filter', params: body, **api_with_body_headers(reader_token)

    expect_success
    expect_number_of_items(AudioRecording.count)

    expect(api_data).to match([{
      id: audio_recording.id,
      site_id: audio_recording.site_id,
      duration_seconds: audio_recording.duration_seconds,
      recorded_date: audio_recording.recorded_date,
      created_at: audio_recording.created_at.iso8601(3)
    }])
  end

  example 'it can retrieve audio recordings entries for visualize' do
    body = {
      filter: { siteId: { in: [audio_recording.site_id] } },
      paging: { disablePaging: true },
      projection: { include: ['id', 'uuid', 'siteId', 'durationSeconds', 'recordedDate'] },
      sorting: { orderBy: 'id', direction: 'asc' }
    }

    post '/audio_recordings/filter', params: body, **api_with_body_headers(reader_token)

    expect_success
    expect_number_of_items(AudioRecording.count)

    expect(api_data).to match([{
      id: audio_recording.id,
      uuid: audio_recording.uuid,
      site_id: audio_recording.site_id,
      duration_seconds: audio_recording.duration_seconds,
      recorded_date: audio_recording.recorded_date
    }])
  end

  context 'when filtering by time of day' do
    let(:perth) {
      perth_site = create(:site)
      project.sites << perth_site
      project.save!
      perth_site
    }

    let(:sydney) {
      sydney_site = create(:site)
      project.sites << sydney_site
      project.save!
      sydney_site
    }

    before do
      # reset recordings
      AudioRecording.delete_all

      # choose a date (1st October 2021) near DST cross-over (3rd October 2021, Sydney time)
      zone = TimeZoneHelper.find_timezone('Australia/Sydney')
      sydney.tzinfo_tz = zone
      sydney.save!

      zone2 = TimeZoneHelper.find_timezone('Australia/Perth')
      perth.tzinfo_tz = zone2
      perth.save!

      # generate recordings every 2-hours at +10:00 (non-DST) for 6 days (3 before and 3 after DST cross over)
      (1..6).each do |day|
        (0...24).step(2).each do |hour|
          recorded_at = Time.new(2021, 10, day, hour, 0, 0, '+10:00')
          create(:audio_recording, recorded_date: recorded_at, duration_seconds: 7200, site_id: sydney.id)
          create(:audio_recording, recorded_date: recorded_at, duration_seconds: 7200, site_id: perth.id)
        end
      end
    end

    around do |example|
      # need to freeze time so that these tests are reasonably interpreted
      # - shifting timezones with multiple timezones being tested is not fun
      original_tz = ::Time.zone
      Zonebie.backend.zone = ::ActiveSupport::TimeZone['UTC']

      example.run

      Zonebie.backend.zone = original_tz
    end

    it 'can filter recordings that overlap the time-of-day range 3 AM to 5 AM, ignoring DST' do
      data = post_filter(filter: {
        site_id: {
          eq: sydney.id
        },
        and: {
          recorded_end_date: {
            gt: { expressions: ['local_offset', 'time_of_day'], value: '03:00' }
          },
          recorded_date: {
            lteq: { expressions: ['local_offset', 'time_of_day'], value: '05:00' }
          }
        }
      })

      # rubocop:disable Layout/LineLength
      # Day                : |----------------- 1--------------| |----------------- 2--------------| |--DD------------- 3--------------| |----------------- 4--------------| |----------------- 5--------------| |----------------- 6--------------|
      # Hour (+10)         : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22
      # Hour (+10/11)      : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23
      # Hour (+08)         : 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20
      # Rec (+10)          : -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
      #                                                                                                 DST ignored in this query!
      # Query Syd (+10/+11):     |--|                                |--|                                |--|                                |--|                                |--|                                |--|
      # Query Perth (+8)   :
      # rubocop:enable Layout/LineLength
      expect(data).to match([
        # these are all +10:00 times
        make_result(site_id: sydney.id, day: 1, hour: 2),
        make_result(site_id: sydney.id, day: 1, hour: 4),
        make_result(site_id: sydney.id, day: 2, hour: 2),
        make_result(site_id: sydney.id, day: 2, hour: 4),
        # DST cross-over is ignored
        make_result(site_id: sydney.id, day: 3, hour: 2),
        make_result(site_id: sydney.id, day: 3, hour: 4),
        make_result(site_id: sydney.id, day: 4, hour: 2),
        make_result(site_id: sydney.id, day: 4, hour: 4),
        make_result(site_id: sydney.id, day: 5, hour: 2),
        make_result(site_id: sydney.id, day: 5, hour: 4),
        make_result(site_id: sydney.id, day: 6, hour: 2),
        make_result(site_id: sydney.id, day: 6, hour: 4)
      ])
    end

    it 'can filter recordings that overlap the time-of-day range 3 AM to 5 AM, adjusting for DST' do
      data = post_filter(filter: {
        site_id: {
          eq: sydney.id
        },
        and: {
          recorded_end_date: {
            gt: { expressions: ['local_tz', 'time_of_day'], value: '03:00' }
          },
          recorded_date: {
            lt: { expressions: ['local_tz', 'time_of_day'], value: '05:00' }
          }
        }
      })

      # rubocop:disable Layout/LineLength
      # Day                : |----------------- 1--------------| |----------------- 2--------------| |--DD------------- 3--------------| |----------------- 4--------------| |----------------- 5--------------| |----------------- 6--------------|
      # Hour (+10)         : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22
      # Hour (+10/11)      : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23
      # Hour (+08)         : 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20
      # Rec (+10)          : -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
      #                                                                                                 DST honored in this query!
      # Query Syd (+10/+11):     |--|                                |--|                               ||                                  ||                                  ||                                  ||
      # Query Perth (+8)   :
      # rubocop:enable Layout/LineLength

      expect(data).to match([
        # these are all +10:00 times
        make_result(site_id: sydney.id, day: 1, hour: 2),
        make_result(site_id: sydney.id, day: 1, hour: 4),
        make_result(site_id: sydney.id, day: 2, hour: 2),
        make_result(site_id: sydney.id, day: 2, hour: 4),
        # DST cross-over is honored
        # Now the query 03:00-05:00 +11:00 is equivalent to:
        #               16:00-18:00 UTC    is equivalent to:
        #               02:00-04:00 +10:00
        make_result(site_id: sydney.id, day: 3, hour: 2),
        make_result(site_id: sydney.id, day: 4, hour: 2),
        make_result(site_id: sydney.id, day: 5, hour: 2),
        make_result(site_id: sydney.id, day: 6, hour: 2)
      ])
    end

    it 'can filter recordings past a day boundary with a composition of filters, 10PM to 1 AM, honoring for DST' do
      data = post_filter(filter: {
        site_id: {
          eq: sydney.id
        },
        and: [
          {
            recorded_date: {
              gteq: '2021-10-03'
            }
          },
          {
            recorded_date: {
              lt: '2021-10-04'
            }
          },
          {
            or: [
              {
                recorded_end_date:
                {
                  gteq: { expressions: ['local_tz', 'time_of_day'], value: '22:00' }
                }
              },
              {
                recorded_date: {
                  lteq: { expressions: ['local_tz', 'time_of_day'], value: '01:00' }
                }
              },
              {
                recorded_end_date:
                {
                  lteq: { expressions: ['local_tz', 'time_of_day'], value: '01:00' }
                }
              },
              {
                recorded_date: {
                  lt: { expressions: ['local_tz', 'time_of_day'], value: '01:00' }
                }
              }
            ]
          }

        ]
      })

      # rubocop:disable Layout/LineLength
      # Day                : |----------------- 1--------------| |----------------- 2--------------| |--DD------------- 3--------------| |----------------- 4--------------| |----------------- 5--------------| |----------------- 6--------------|
      # Hour (UTC)         : 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12
      # Hour (+10)         : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22
      # Hour (+10/11)      : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23
      # Hour (+08)         : 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20
      # Rec (+10)          : -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
      #                                                                                                 DST honored in this query!
      # Query Syd (+10/+11):                                                                                        xxxxxxxxxxxxxxxx|---|xxxxxxxxxxxxxx
      # Query Perth (+8)   :
      # rubocop:enable Layout/LineLength

      expect(data).to match([
        # these are all +10:00 times

        # DST cross-over is honored - the hour shift moves the the edge of 1am which is the next recording
        make_result(site_id: sydney.id, day: 3, hour: 20),
        make_result(site_id: sydney.id, day: 3, hour: 22),
        make_result(site_id: sydney.id, day: 4, hour: 0)

      ])
    end

    it 'can filter for recordings by exact start time only (6 PM local time), ignoring DST' do
      data = post_filter(filter: {
        recorded_date: {
          eq: { expressions: ['local_offset', 'time_of_day'], value: '18:00' }
        }
      })

      # rubocop:disable Layout/LineLength
      # Day                : |----------------- 1--------------| |----------------- 2--------------| |--DD------------- 3--------------| |----------------- 4--------------| |----------------- 5--------------| |----------------- 6--------------|
      # Hour (+10)         : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22
      # Hour (+10/11)      : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23
      # Hour (+08)         : 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20
      # Rec (+10)          : -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
      #                                                                                                 DST ignored in this query!
      # Query Syd (+10/+11):                            =                                   =                                   =                                   =                                   =                                   =
      # Query Perth (+8)   :                               =                                   =                                   =                                   =                                   =                                   =
      # rubocop:enable Layout/LineLength

      # we should find recordings from
      # +10:00 Sydney & +08:00 Perth
      # and after DST, +11:00 Sydney & +08:00 Perth (no DST in Perth)
      # but since local_offset is used we get consistent selections back
      expect(data).to match([
        # these are all +10:00 times
        make_result(site_id: sydney.id, day: 1, hour: 18),
        make_result(site_id: perth.id, day: 1, hour: 20),
        make_result(site_id: sydney.id, day: 2, hour: 18),
        make_result(site_id: perth.id, day: 2, hour: 20),
        # DST cross-over (no effect)
        make_result(site_id: sydney.id, day: 3, hour: 18),
        make_result(site_id: perth.id, day: 3, hour: 20),
        make_result(site_id: sydney.id, day: 4, hour: 18),
        make_result(site_id: perth.id, day: 4, hour: 20),
        make_result(site_id: sydney.id, day: 5, hour: 18),
        make_result(site_id: perth.id, day: 5, hour: 20),
        make_result(site_id: sydney.id, day: 6, hour: 18),
        make_result(site_id: perth.id, day: 6, hour: 20)
      ])
    end

    it 'can filter for recordings by exact start time only (6 PM local time), adjusting for DST' do
      data = post_filter(filter: {
        recorded_date: {
          eq: { expressions: ['local_tz', 'time_of_day'], value: '18:00' }
        }
      })

      # rubocop:disable Layout/LineLength
      # Day                : |----------------- 1--------------| |----------------- 2--------------| |--DD------------- 3--------------| |----------------- 4--------------| |----------------- 5--------------| |----------------- 6--------------|
      # Hour (+10)         : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22
      # Hour (+10/11)      : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23
      # Hour (+08)         : 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20
      # Rec (+10)          : -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
      #                                                                                                 DST honored in this query!
      # Query Syd (+10/+11):                            =                                   =                                    !                                   !                                   !                                   !
      # Query Perth (+8)   :                               =                                   =                                   =                                   =                                   =                                   =
      # rubocop:enable Layout/LineLength

      # we should find recordings from
      # +10:00 Sydney & +08:00 Perth
      # and after DST, +11:00 Sydney & +08:00 Perth (no DST in Perth)
      # however, since local_tz is used we get inconsistent selections back
      # No recordings start at 6PM DST time in Sydney
      expect(data).to match([
        # these are all +10:00 times
        make_result(site_id: sydney.id, day: 1, hour: 18),
        make_result(site_id: perth.id, day: 1, hour: 20),
        make_result(site_id: sydney.id, day: 2, hour: 18),
        make_result(site_id: perth.id, day: 2, hour: 20),

        # DST cross-over - now no recordings in Sydney start at 18:00
        make_result(site_id: perth.id, day: 3, hour: 20),
        make_result(site_id: perth.id, day: 4, hour: 20),
        make_result(site_id: perth.id, day: 5, hour: 20),
        make_result(site_id: perth.id, day: 6, hour: 20)
      ])
    end

    it 'can filter for recordings by exact *end* time only (8 AM local time), adjusting for DST' do
      data = post_filter(filter: {
        recorded_end_date: {
          eq: { expressions: ['local_tz', 'time_of_day'], value: '08:00' }
        }
      })

      # rubocop:disable Layout/LineLength
      # Day                : |----------------- 1--------------| |----------------- 2--------------| |--DD------------- 3--------------| |----------------- 4--------------| |----------------- 5--------------| |----------------- 6--------------|
      # Hour (+10)         : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22
      # Hour (+10/11)      : 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23 01 03 05 07 09 11 13 15 17 19 21 23
      # Hour (+08)         : 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20 22 00 02 04 06 08 10 12 14 16 18 20
      # Rec (+10)          : -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
      #                                                                                                 DST honored in this query!
      # Query Syd (+10/+11):           =                                   =                                    !                                   !                                   !                                   !
      # Query Perth (+8)   :              =                                   =                                   =                                   =                                   =                                   =
      # rubocop:enable Layout/LineLength

      # we should find recordings from
      # +10:00 Sydney & +08:00 Perth
      # and after DST, +11:00 Sydney & +08:00 Perth (no DST in Perth)
      # however, since local_tz is used we get inconsistent selections back
      expect(data).to match([
        # these are all +10:00 times
        make_result(site_id: sydney.id, day: 1, hour: 6),
        make_result(site_id: perth.id, day: 1, hour: 8),
        make_result(site_id: sydney.id, day: 2, hour: 6),
        make_result(site_id: perth.id, day: 2, hour: 8),
        # DST cross-over - now no recordings in Sydney end at 08:00
        make_result(site_id: perth.id, day: 3, hour: 8),
        make_result(site_id: perth.id, day: 4, hour: 8),
        make_result(site_id: perth.id, day: 5, hour: 8),
        make_result(site_id: perth.id, day: 6, hour: 8)
      ])
    end

    it 'can filter for recordings and not produce column conflicts for tzinfo' do
      # https://github.com/QutEcoacoustics/baw-server/issues/566
      data = post_filter(filter: {
        'projects.id': { eq: 1 },
        recorded_end_date: {
          greater_than_or_equal: { expressions: ['local_offset', 'time_of_day'], value: '07:00' }
        },
        recorded_date: {
          less_than_or_equal: { expressions: ['local_offset', 'time_of_day'], value: '07:01' }
        }
      }, projection:  { include: ['id', 'recorded_date', 'sites.name', 'site_id', 'canonical_file_name', 'recorded_date_timezone'] })

      expect(data).to match([
        # these are all +10:00 times
        make_result(site_id: sydney.id, day: 1, hour: 6),
        make_result(site_id: perth.id, day: 1, hour: 8),
        make_result(site_id: sydney.id, day: 2, hour: 6),
        make_result(site_id: perth.id, day: 2, hour: 8),

        make_result(site_id: sydney.id, day: 3, hour: 6),
        make_result(site_id: perth.id, day: 3, hour: 8),
        make_result(site_id: sydney.id, day: 4, hour: 6),
        make_result(site_id: perth.id, day: 4, hour: 8),
        make_result(site_id: sydney.id, day: 5, hour: 6),
        make_result(site_id: perth.id, day: 5, hour: 8),
        make_result(site_id: sydney.id, day: 6, hour: 6),
        make_result(site_id: perth.id, day: 6, hour: 8)
      ])
    end

    def post_filter(filter:, projection: nil)
      projection ||= { include: [:recorded_date_timezone, :recorded_date, :site_id] }
      body = {
        filter:,
        projection:,
        sorting: { orderBy: 'recorded_date', direction: 'asc' }
      }

      post '/audio_recordings/filter', params: body, **api_with_body_headers(reader_token)

      expect_success

      # manipulate the response so the dates are all are actual Time objects and can be compared by rspec
      # Also ensure all results are compared in the +10:00 TZ - again for readability
      data = api_data
      data.each do |result|
        result[:recorded_date] = Time.iso8601(result[:recorded_date]).getlocal('+10:00')
      end
      data.sort_by { |result|
        [result[:recorded_date], result[:site_id]]
      }
    end

    def make_result(site_id:, day:, hour:)
      a_hash_including({
        site_id:,
        recorded_date: Time.new(2021, 10, day, hour, 0, 0, '+10:00'),
        recorded_date_timezone: case site_id
                                when sydney.id
                                  'Australia/Sydney'
                                when perth.id
                                  'Australia/Perth'
                                else
                                  raise 'unexpected case'
                                end
      })
    end
  end
end
