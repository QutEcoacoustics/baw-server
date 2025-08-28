# frozen_string_literal: true

describe '/audio_events' do
  create_entire_hierarchy

  # projects update/create actions expect payload from html form as well as json
  describe 'Downloading Csv' do
    def download_url
      "/audio_recordings/#{audio_recording.id}/audio_events/download"
    end

    it 'downloads csv file with no leading spaces in headers' do
      get download_url, params: nil, headers: auth_header(admin_token)
      expect(response).to have_http_status(:ok)
      column_headers = 'audio_event_id,audio_recording_id,audio_recording_uuid,audio_recording_start_date_utc_00_00,' \
                       'audio_recording_start_time_utc_00_00,audio_recording_start_datetime_utc_00_00,event_created_at_date_utc_00_00,' \
                       'event_created_at_time_utc_00_00,event_created_at_datetime_utc_00_00,projects,region_id,region_name,site_id,site_name,' \
                       'event_start_date_utc_00_00,event_start_time_utc_00_00,event_start_datetime_utc_00_00,event_start_seconds,' \
                       'event_end_seconds,event_duration_seconds,low_frequency_hertz,high_frequency_hertz,is_reference,created_by,' \
                       'updated_by,common_name_tags,common_name_tag_ids,species_name_tags,species_name_tag_ids,other_tags,other_tag_ids,' \
                       'verifications,verification_counts,verification_correct,verification_incorrect,verification_skip,verification_unsure,' \
                       'verification_decisions,verification_consensus,audio_event_import_file_id,audio_event_import_file_name,' \
                       'audio_event_import_id,audio_event_import_name,' \
                       "listen_url,library_url\n"
      expect(response.body).to start_with(column_headers)
    end
  end

  # AT 2021: disabled. Nested associations are extremely complex,
  # and as far as we are aware, they are not used anywhere in production
  # TODO: remove on passing test suite
  # context 'when creating' do
  #   it 'will accept new and existing tags as nested attributes' do
  #     existing_tag = FactoryBot.create(:tag, text: 'existing')
  #     body = {
  #       audio_event: FactoryBot.attributes_for(:audio_event)
  #     }
  #     body[:audio_event][:tags_attributes] = [
  #       # new
  #       FactoryBot.attributes_for(:tag),
  #       # an existing tag
  #       {
  #         id: existing_tag.id,
  #         is_taxonomic: existing_tag.is_taxonomic,
  #         text: existing_tag.text,
  #         type_of_tag: existing_tag.type_of_tag,
  #         retired: existing_tag.retired
  #       }
  #     ]
  #     logger.info('existing taggings', body: body)
  #     logger.info('existing taggings', taggings: Tagging.all)
  #     tags_count = Tag.count
  #     post "/audio_recordings/#{audio_recording.id}/audio_events",
  #          params: body, headers: api_with_body_headers(writer_token), as: :json

  #     expect_success
  #     expect(Tag.count).to eq(1 + tags_count)
  #     expect(api_result).to include({
  #       data: a_hash_including({
  #         taggings: [
  #           hash_including({ tag_id: existing_tag.id }),
  #           hash_including({ id: existing_tag.id + 1 })
  #         ]
  #       })
  #     })
  #   end
  # end

  describe 'Updating an audio event' do
    it 'accepts valid time and frequency values' do
      body = {
        audio_event: {
          start_time_seconds: 5.0,
          end_time_seconds: 10.0,
          low_frequency_hertz: 1000,
          high_frequency_hertz: 2000
        }
      }
      patch "/audio_recordings/#{audio_recording.id}/audio_events/#{audio_event.id}",
        params: body, **api_with_body_headers(writer_token)
      expect_success
    end

    it 'accepts a reference field' do
      body = {
        audio_event: {
          is_reference: true
        }
      }
      patch "/audio_recordings/#{audio_recording.id}/audio_events/#{audio_event.id}",
        params: body, **api_with_body_headers(writer_token)
      expect_success
    end

    it 'accepts a channel field' do
      body = {
        audio_event: {
          channel: 2
        }
      }

      patch "/audio_recordings/#{audio_recording.id}/audio_events/#{audio_event.id}",
        params: body, **api_with_body_headers(writer_token)

      expect_success
      expect(audio_event.reload.channel).to eq(2)
    end
  end

  context 'when filtering' do
    let(:second_audio_recording) {
      create(:audio_recording, creator: reader_user, site:, recorded_date: Time.new(2020, 1, 1, 5, 2, 0, '+10:00'))
    }

    let!(:isolated_audio_event) {
      # intentionally completely isolated hierarchy
      create(
        :audio_event,
        start_time_seconds: 10,
        end_time_seconds: 11
      )
    }

    before do
      create(
        :audio_event,
        creator: reader_user, audio_recording:, is_reference: true,
        start_time_seconds: 5.2, end_time_seconds: 5.8
      )
      create(
        :audio_event,
        creator: reader_user, audio_recording:, is_reference: true,
        start_time_seconds: 4.0, end_time_seconds: 5.8,
        audio_event_import_file:
      )
      create(
        :audio_event,
        creator: reader_user, audio_recording: second_audio_recording, is_reference: true,
        start_time_seconds: 5.4, end_time_seconds: 5.8
      )

      create(
        :read_permission,
        creator: owner_user,
        user: reader_user,
        project: isolated_audio_event.audio_recording.site.region.project
      )

      site.tzinfo_tz = 'Australia/Brisbane'
      site.save!
    end

    it 'can sort by and project duration_seconds' do
      # projection and sorting are done at the same time to test the combination
      filter =   {
        'filter' => {
          'isReference' => { 'eq' => true }
        },
        'paging' => { 'items' => 10, 'page' => 1 },
        'projection' => {
          'include' => ['id', 'start_time_seconds', 'end_time_seconds', 'durationSeconds', 'is_reference']
        },
        'sorting' => {
          'orderBy' => 'durationSeconds',
          'direction' => 'desc'
        },
        'format' => 'json',
        'controller' => 'audio_events',
        'action' => 'filter',
        'audio_event' => {}
      }

      post '/audio_events/filter', params: filter, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(3)
      expect(api_data).to all(include(is_reference: be(true)))
      expect(api_data).to match [
        a_hash_including(start_time_seconds: 4.0, end_time_seconds: 5.8),
        a_hash_including(start_time_seconds: 5.2, end_time_seconds: 5.8),
        a_hash_including(start_time_seconds: 5.4, end_time_seconds: 5.8)
      ]
    end

    it 'can filter by audio_event_import' do
      body = {
        filter: {
          'audio_event_imports.id' => {
            eq: audio_event_import.id
          }
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      # plus one that already existed from the hierarchy
      expect_number_of_items(2)
      expect(api_data).to match [
        a_hash_including(start_time_seconds: 4.0, end_time_seconds: 5.8, is_reference: true),
        # the defaults values for audio event factory from the existing hierarchy
        a_hash_including(start_time_seconds: 5.2, end_time_seconds: 5.8, is_reference: false)
      ]
    end

    it 'can filter by audio_event_import_file file names for analysis job results' do
      event = build(:audio_event_import_file, path: 'ology.csv', analysis_jobs_item:)
        .tap { |import| import.save(validate: false) }
        .then { |import| create(:audio_event, creator: reader_user, audio_recording:, audio_event_import_file: import) }

      body = {
        filter: {
          'audio_event_import_files.name' => {
            contains: 'ology'
          }
        },
        projection: {
          include: ['audio_event_import_files.name', 'id']
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(reader_token)

      expect_success

      expect_number_of_items(1)
      expect(api_data.first[:id]).to eq(event.id)
    end

    it 'can filter by audio_event_import_file file names for uploaded files' do
      event = build(:audio_event_import_file, :with_file)
        .tap { |import| import.save(validate: false) }
        .then { |import| create(:audio_event, creator: reader_user, audio_recording:, audio_event_import_file: import) }

      body = {
        filter: {
          'audio_event_import_files.name' => {
            contains: 'csv'
          }
        },
        projection: {
          include: ['audio_event_import_files.name', 'id']
        },
        sorting: {
          order_by: 'audio_event_import_files.name',
          direction: 'asc'
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(reader_token)

      expect_success

      # why 3?
      # - 2 exiting files were made for existing audio events (and these simulate analysis job results)
      # - 1 new file was 'uploaded' and is the fixture created for this test
      expect_number_of_items(3)
      existing_ids = AudioEvent.all.where.not(audio_event_import_file: nil).pluck(:id).to_set
      existing_ids.add(event.id)
      expect(api_data.pluck(:id)).to match_array(existing_ids)
    end

    it 'can filter by events that are verified' do
      # filter by audio_event verified is asking for audio events that have at
      # least one tagging with a verification
      body = {
        filter: {
          'verifications.id' => {
            not_eq: nil
          }
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(reader_token)

      expect_success

      expect_number_of_items(1)
      expect(AudioEvent.count).to eq 5

      expect(api_data.first[:id])
        .to eq(audio_event.id)
        .and eq(verification.audio_event_id)
    end

    it 'can filter by with an overlapping start and end time' do
      body = {
        filter: {
          'start_time_seconds' => {
            lt: 5
          },
          'end_time_seconds' => {
            gt: 4
          }
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(1)
      expect(api_data).to match [
        a_hash_including(start_time_seconds: 4.0, end_time_seconds: 5.8, is_reference: true)
      ]
    end

    it 'can filter by audio_recording.recorded_end_date' do
      filter = {
        'filter' => {
          'audio_recordings.recorded_end_date' => { 'lt' => second_audio_recording.recorded_date }
        },
        'projection' => {
          'include' => ['audio_recordings.recorded_end_date', 'id']
        },
        'sorting' => {
          'order_by' => 'id',
          'direction' => 'asc'
        }
      }

      post '/audio_events/filter', params: filter, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(4)

      # so this is a little tricky: we are filtering events by the end date of their recordings.
      # because we have one event that is attached to the second recording, the end date of that recording
      # is EQUAL to the filter date (the recording's end date), thus it is excluded from the results.
      #
      # Rather if we had filtered by the end_date of the event, then it would have been included because the
      # event's end obviously occurs before the recording's end date.
      expected = AudioEvent
        .joins(:audio_recording)
        .where.not(audio_recording_id: second_audio_recording.id)
        .select(:id, AudioRecording.arel_recorded_end_date.as('audio_recording.recorded_end_date'))
        .order(:id)
        .map { |event|
          a_hash_including(
            id: event.id,
            'audio_recordings.recorded_end_date': event['audio_recording.recorded_end_date'].iso8601(3)
          )
        }
      expect(api_data).to match expected
    end

    it 'can filter by project id' do
      body = {
        filter: {
          'projects.id' => {
            eq: isolated_audio_event.audio_recording.site.region.project.id
          }
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(1)
      expect(api_data).to match [
        a_hash_including(start_time_seconds: 10, end_time_seconds: 11, is_reference: false)
      ]
    end

    it 'can filter by project name' do
      body = {
        filter: {
          'projects.name' => {
            contains: isolated_audio_event.audio_recording.site.region.project.name
          }
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(1)
      expect(api_data).to match [
        a_hash_including(start_time_seconds: 10, end_time_seconds: 11, is_reference: false)
      ]
    end

    it 'can filter by region id' do
      body = {
        filter: {
          'regions.id' => {
            eq: isolated_audio_event.audio_recording.site.region.id
          }
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(1)
      expect(api_data).to match [
        a_hash_including(start_time_seconds: 10, end_time_seconds: 11, is_reference: false)
      ]
    end

    it 'can filter by site id' do
      body = {
        filter: {
          'sites.id' => {
            eq: isolated_audio_event.audio_recording.site.id
          }
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(1)
      expect(api_data).to match [
        a_hash_including(start_time_seconds: 10, end_time_seconds: 11, is_reference: false)
      ]
    end

    it 'can filter by audio events absolute start and end dates' do
      # date + 5.4 to date + 5.8
      body = {
        filter: {
          'start_date' => {
            lt: '2020-01-01T05:02:10+10:00'
          },
          'end_date' => {
            gt: '2020-01-01T05:02:05+10:00'
          }
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(1)
      expect(api_data).to match [
        a_hash_including(
          start_time_seconds: 5.4,
          end_time_seconds: 5.8,
          is_reference: true,
          audio_recording_id: second_audio_recording.id
        )
      ]
    end

    it 'can filter by audio events by times of day' do
      # date + 5.4 to date + 5.8
      body = {
        filter: {
          'start_date' => {
            lt: { expressions: ['local_offset', 'time_of_day'], value: '06:00' }
          },
          'end_date' => {
            gt: { expressions: ['local_offset', 'time_of_day'], value: '05:00' }
          }
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(reader_token)

      expect_success
      expect_number_of_items(1)
      expect(api_data).to match [
        a_hash_including(
          start_time_seconds: 5.4,
          end_time_seconds: 5.8,
          is_reference: true,
          audio_recording_id: second_audio_recording.id
        )
      ]
    end
  end

  context('with reference events') do
    let(:another_user) {
      create(:user, user_name: 'bob dole')
    }

    let(:another_audio_recording) {
      create(:audio_recording, creator: another_user, site:)
    }

    before do
      [true, true, false].each do |is_reference|
        create(
          :audio_event,
          creator: another_user, audio_recording: another_audio_recording, is_reference: is_reference
        )
      end
    end

    it 'are accessible with a no access user' do
      body = {
        filter: {
          'start_time_seconds' => {
            gt: 0
          },
          'end_time_seconds' => {
            lt: 10
          }
        }
      }

      post '/audio_events/filter', params: body, **api_with_body_headers(no_access_user)

      expect_success
      expect_number_of_items(2)
      expect(api_data).to include(
        a_hash_including(start_time_seconds: 5.2, end_time_seconds: 5.8, is_reference: true)
      ).exactly(2).times
    end
  end
end
