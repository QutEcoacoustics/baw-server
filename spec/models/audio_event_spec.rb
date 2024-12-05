# frozen_string_literal: true

# == Schema Information
#
# Table name: audio_events
#
#  id                                                                              :integer          not null, primary key
#  channel                                                                         :integer
#  deleted_at                                                                      :datetime
#  end_time_seconds                                                                :decimal(10, 4)
#  high_frequency_hertz                                                            :decimal(10, 4)
#  import_file_index(Index of the row/entry in the file that generated this event) :integer
#  is_reference                                                                    :boolean          default(FALSE), not null
#  low_frequency_hertz                                                             :decimal(10, 4)
#  score(Score or confidence for this event.)                                      :decimal(, )
#  start_time_seconds                                                              :decimal(10, 4)   not null
#  created_at                                                                      :datetime
#  updated_at                                                                      :datetime
#  audio_event_import_file_id                                                      :integer
#  audio_recording_id                                                              :integer          not null
#  creator_id                                                                      :integer          not null
#  deleter_id                                                                      :integer
#  provenance_id(Source of this event)                                             :integer
#  updater_id                                                                      :integer
#
# Indexes
#
#  index_audio_events_on_audio_event_import_file_id  (audio_event_import_file_id)
#  index_audio_events_on_audio_recording_id          (audio_recording_id)
#  index_audio_events_on_creator_id                  (creator_id)
#  index_audio_events_on_deleter_id                  (deleter_id)
#  index_audio_events_on_provenance_id               (provenance_id)
#  index_audio_events_on_updater_id                  (updater_id)
#
# Foreign Keys
#
#  audio_events_audio_recording_id_fk  (audio_recording_id => audio_recordings.id) ON DELETE => cascade
#  audio_events_creator_id_fk          (creator_id => users.id)
#  audio_events_deleter_id_fk          (deleter_id => users.id)
#  audio_events_updater_id_fk          (updater_id => users.id)
#  fk_rails_...                        (audio_event_import_file_id => audio_event_import_files.id) ON DELETE => cascade
#  fk_rails_...                        (provenance_id => provenances.id)
#
describe AudioEvent do
  subject { build(:audio_event) }

  it 'has a valid factory' do
    expect(create(:audio_event)).to be_valid
  end

  it 'can have a blank end time' do
    ae = build(:audio_event, end_time_seconds: nil)
    expect(ae).to be_valid
  end

  it 'can have a blank high frequency' do
    expect(build(:audio_event, high_frequency_hertz: nil)).to be_valid
  end

  it 'can have a blank end time and a blank high frequency' do
    expect(build(:audio_event, { end_time_seconds: nil, high_frequency_hertz: nil })).to be_valid
  end

  it { is_expected.to belong_to(:audio_recording) }
  it { is_expected.to belong_to(:audio_event_import_file).optional }
  it { is_expected.to belong_to(:provenance).optional }
  it { is_expected.to belong_to(:creator) }
  it { is_expected.to belong_to(:updater).optional }
  it { is_expected.to belong_to(:deleter).optional }

  it { is_expected.to have_many(:tags) }
  # AT 2021: disabled. Nested associations are extremely complex,
  # and as far as we are aware, they are not used anywhere in production
  it { is_expected.not_to accept_nested_attributes_for(:tags) }

  # this test is not possible, since everything is converted to a bool when set to :is_reference...
  #it { is_expected.to validate_inclusion_of(:is_reference).in_array([true, false]) }

  it { is_expected.to validate_presence_of(:start_time_seconds) }
  it { is_expected.to validate_numericality_of(:start_time_seconds).is_greater_than_or_equal_to(0) }

  it { is_expected.to validate_numericality_of(:end_time_seconds).is_greater_than_or_equal_to(0).allow_nil }

  it { is_expected.to validate_presence_of(:low_frequency_hertz) }
  it { is_expected.to validate_numericality_of(:low_frequency_hertz).is_greater_than_or_equal_to(0) }

  it { is_expected.to validate_numericality_of(:high_frequency_hertz).is_greater_than_or_equal_to(0).allow_nil }

  it 'is invalid if the end time is less than the start time' do
    expect(build(:audio_event, { start_time_seconds: 100.320, end_time_seconds: 10.360 })).not_to be_valid
  end

  it 'is invalid if the end frequency is less then the low frequency' do
    expect(build(:audio_event, { low_frequency_hertz: 1000, high_frequency_hertz: 100 })).not_to be_valid
  end

  it 'has a recent scope' do
    create_list(:audio_event, 20)

    events = AudioEvent.most_recent(5).to_a
    expect(events).to have(5).items
    expect(AudioEvent.order(created_at: :desc).limit(5).to_a).to eq(events)
  end

  it 'has a total duration scope' do
    create_list(:audio_event, 10) do |item|
      item.start_time_seconds = 0
      item.end_time_seconds = 60
      item.save!
    end

    total = AudioEvent.total_duration_seconds
    expect(total).to an_instance_of(BigDecimal)
    expect(total).to eq(600)
  end

  it 'has a recent_within scope' do
    old = create(:audio_event, created_at: 2.months.ago)

    actual = AudioEvent.created_within(1.month.ago)
    expect(actual.count).to eq(AudioEvent.count - 1)
    expect(actual).not_to include(old)
  end

  it 'constructs the expected sql for annotation download (timezone: UTC)' do
    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil)

    sql = <<~SQL.squish
      SELECT"audio_events"."id"
      AS "audio_event_id","audio_recordings"."id"
      AS "audio_recording_id","audio_recordings"."uuid"
      AS "audio_recording_uuid",to_char("audio_recordings"."recorded_date" +
      INTERVAL '0 seconds', 'YYYY-MM-DD')
      AS "audio_recording_start_date_utc_00_00",to_char("audio_recordings"."recorded_date" +
      INTERVAL '0 seconds', 'HH24:MI:SS')
      AS "audio_recording_start_time_utc_00_00",to_char("audio_recordings"."recorded_date" +
      INTERVAL '0 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
      AS "audio_recording_start_datetime_utc_00_00",to_char("audio_events"."created_at" +
      INTERVAL '0 seconds', 'YYYY-MM-DD')
      AS "event_created_at_date_utc_00_00",to_char("audio_events"."created_at" +
      INTERVAL '0 seconds', 'HH24:MI:SS')
      AS "event_created_at_time_utc_00_00",to_char("audio_events"."created_at" +
      INTERVAL '0 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
      AS "event_created_at_datetime_utc_00_00",(
             SELECT string_agg(
               CAST("projects"."id" as varchar) || ':' || "projects"."name", '|')
      FROM "projects_sites"
      INNER
      JOIN "projects"
      ON "projects"."id" = "projects_sites"."project_id"
      WHERE "projects"."deleted_at"
      IS
      NULL
      AND "projects_sites"."site_id" = "sites"."id") "projects", "sites"."id"
      AS "site_id", "sites"."name"
      AS "site_name",to_char("audio_recordings"."recorded_date" +
      CAST("audio_events"."start_time_seconds" || ' seconds' as interval) +
      INTERVAL '0 seconds', 'YYYY-MM-DD')
      AS "event_start_date_utc_00_00",to_char("audio_recordings"."recorded_date" +
      CAST("audio_events"."start_time_seconds" || ' seconds' as interval) +
      INTERVAL '0 seconds', 'HH24:MI:SS')
      AS "event_start_time_utc_00_00",to_char("audio_recordings"."recorded_date" +
      CAST("audio_events"."start_time_seconds" || ' seconds' as interval) +
      INTERVAL '0 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
      AS "event_start_datetime_utc_00_00","audio_events"."start_time_seconds"
      AS "event_start_seconds","audio_events"."end_time_seconds"
      AS "event_end_seconds",("audio_events"."end_time_seconds" - "audio_events"."start_time_seconds")
      AS "event_duration_seconds","audio_events"."low_frequency_hertz"
      AS "low_frequency_hertz","audio_events"."high_frequency_hertz"
      AS "high_frequency_hertz","audio_events"."is_reference"
      AS "is_reference","audio_events"."creator_id"
      AS "created_by", "audio_events"."updater_id"
      AS "updated_by",(
        SELECT string_agg(
          CAST("tags"."id" as varchar) || ':' || "tags"."text", '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND "tags"."type_of_tag" = 'common_name') "common_name_tags",(
        SELECT string_agg(
          CAST("tags"."id" as varchar), '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND "tags"."type_of_tag" = 'common_name') "common_name_tag_ids",(
        SELECT string_agg(
          CAST("tags"."id" as varchar) || ':' || "tags"."text", '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND "tags"."type_of_tag" = 'species_name') "species_name_tags",(
        SELECT string_agg(
          CAST("tags"."id" as varchar), '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND "tags"."type_of_tag" = 'species_name') "species_name_tag_ids",(
        SELECT string_agg(
          CAST("tags"."id" as varchar) || ':' || "tags"."text" || ':' || "tags"."type_of_tag", '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND
      NOT ("tags"."type_of_tag"
      IN ('species_name', 'common_name'))) "other_tags",(
        SELECT string_agg(
          CAST("tags"."id" as varchar), '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND
      NOT ("tags"."type_of_tag"
      IN ('species_name', 'common_name'))) "other_tag_ids",'http://web/listen/'|| "audio_recordings"."id" || '?start=' || (floor("audio_events"."start_time_seconds" / 30) * 30) || '&end=' || ((floor("audio_events"."start_time_seconds" / 30) * 30) + 30)
      AS "listen_url",'http://web/library/' || "audio_recordings"."id" || '/audio_events/' || audio_events.id
      AS "library_url"
      FROM "audio_events"
      INNER
      JOIN "users"
      ON "users"."id" = "audio_events"."creator_id"
      INNER
      JOIN "audio_recordings"
      ON "audio_recordings"."id" = "audio_events"."audio_recording_id"
      INNER
      JOIN "sites"
      ON "sites"."id" = "audio_recordings"."site_id"
      WHERE "audio_events"."deleted_at"
      IS
      NULL
      AND "audio_recordings"."deleted_at"
      IS
      NULL
      AND "sites"."deleted_at"
      IS
      NULL
      AND "sites"."id"
      IN (
        SELECT
      DISTINCT "sites"."id"
      FROM "projects"
      INNER
      JOIN "projects_sites"
      ON "projects"."id" = "projects_sites"."project_id"
      WHERE "projects"."deleted_at"
      IS
      NULL
      AND "sites"."id" = "projects_sites"."site_id")

      ORDER
      BY "audio_events"."id"
      DESC
    SQL

    a_mod = query.to_sql.gsub(/\s*([A-Z]+)/, "\n\\1").gsub(/(\t| )+/, '').trim('\n')
    b_mod = sql.gsub(/\s*([A-Z]+)/, "\n\\1").gsub(/(\t| )+/, '').trim('\n')
    expect(a_mod).to eq(b_mod)
  end

  it 'constructs the expected sql for annotation download (timezone:
 Brisbane)' do
    query =
      AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, 'Brisbane')

    sql = <<~SQL.squish
      SELECT "audio_events"."id"
      AS "audio_event_id","audio_recordings"."id"
      AS "audio_recording_id","audio_recordings"."uuid"
      AS "audio_recording_uuid",to_char("audio_recordings"."recorded_date" +
      INTERVAL '36000 seconds', 'YYYY-MM-DD')
      AS "audio_recording_start_date_brisbane_10_00", to_char("audio_recordings"."recorded_date" +
      INTERVAL '36000 seconds', 'HH24:MI:SS')
      AS "audio_recording_start_time_brisbane_10_00",to_char("audio_recordings"."recorded_date" +
      INTERVAL '36000 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"+10:00"')
      AS "audio_recording_start_datetime_brisbane_10_00",to_char("audio_events"."created_at" +
      INTERVAL '36000 seconds', 'YYYY-MM-DD')
      AS "event_created_at_date_brisbane_10_00",to_char("audio_events"."created_at" +
      INTERVAL '36000 seconds', 'HH24:MI:SS')
      AS "event_created_at_time_brisbane_10_00",to_char("audio_events"."created_at" +
      INTERVAL '36000 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"+10:00"')
      AS "event_created_at_datetime_brisbane_10_00",(
        SELECT string_agg(
          CAST("projects"."id" as varchar) || ':' || "projects"."name", '|')
      FROM "projects_sites"
      INNER
      JOIN "projects"
      ON "projects"."id" = "projects_sites"."project_id"
      WHERE "projects"."deleted_at"
      IS
      NULL
      AND "projects_sites"."site_id" = "sites"."id") "projects", "sites"."id"
      AS "site_id", "sites"."name"
      AS "site_name",to_char("audio_recordings"."recorded_date" +
      CAST("audio_events"."start_time_seconds" || ' seconds' as interval) +
      INTERVAL '36000 seconds', 'YYYY-MM-DD')
      AS "event_start_date_brisbane_10_00",to_char("audio_recordings"."recorded_date" +
      CAST("audio_events"."start_time_seconds" || ' seconds' as interval) +
      INTERVAL '36000 seconds', 'HH24:MI:SS')
      AS "event_start_time_brisbane_10_00",to_char("audio_recordings"."recorded_date" +
      CAST("audio_events"."start_time_seconds" || ' seconds' as interval) +
      INTERVAL '36000 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"+10:00"')
      AS "event_start_datetime_brisbane_10_00","audio_events"."start_time_seconds"
      AS "event_start_seconds","audio_events"."end_time_seconds"
      AS "event_end_seconds",("audio_events"."end_time_seconds" - "audio_events"."start_time_seconds")
      AS "event_duration_seconds","audio_events"."low_frequency_hertz"
      AS "low_frequency_hertz","audio_events"."high_frequency_hertz"
      AS "high_frequency_hertz","audio_events"."is_reference"
      AS "is_reference","audio_events"."creator_id"
      AS "created_by", "audio_events"."updater_id"
      AS "updated_by",(
        SELECT string_agg(
          CAST("tags"."id" as varchar) || ':' || "tags"."text", '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND "tags"."type_of_tag" = 'common_name') "common_name_tags",(
        SELECT string_agg(
          CAST("tags"."id" as varchar), '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND "tags"."type_of_tag" = 'common_name') "common_name_tag_ids",(
        SELECT string_agg(
          CAST("tags"."id" as varchar) || ':' || "tags"."text", '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND "tags"."type_of_tag" = 'species_name') "species_name_tags",(
             SELECT string_agg(
               CAST("tags"."id" as varchar), '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND "tags"."type_of_tag" = 'species_name') "species_name_tag_ids",(
        SELECT string_agg(
          CAST("tags"."id" as varchar) || ':' || "tags"."text" || ':' || "tags"."type_of_tag", '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND
      NOT ("tags"."type_of_tag"
      IN ('species_name', 'common_name'))) "other_tags",(
        SELECT string_agg(
          CAST("tags"."id" as varchar), '|')
      FROM "tags"
      INNER
      JOIN "audio_events_tags"
      ON "audio_events_tags"."tag_id" = "tags"."id"
      WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id"
      AND
      NOT ("tags"."type_of_tag"
      IN ('species_name', 'common_name'))) "other_tag_ids",'http://web/listen/'|| "audio_recordings"."id" || '?start=' || (floor("audio_events"."start_time_seconds" / 30) * 30) || '&end=' || ((floor("audio_events"."start_time_seconds" / 30) * 30) + 30)
      AS "listen_url",'http://web/library/' || "audio_recordings"."id" || '/audio_events/' || audio_events.id
      AS "library_url"
      FROM "audio_events"
      INNER
      JOIN "users"
      ON "users"."id" = "audio_events"."creator_id"
      INNER
      JOIN "audio_recordings"
      ON "audio_recordings"."id" = "audio_events"."audio_recording_id"
      INNER
      JOIN "sites"
      ON "sites"."id" = "audio_recordings"."site_id"
      WHERE "audio_events"."deleted_at"
      IS
      NULL
      AND "audio_recordings"."deleted_at"
      IS
      NULL
      AND "sites"."deleted_at"
      IS
      NULL
      AND "sites"."id"
      IN (
        SELECT
      DISTINCT "sites"."id"
      FROM "projects"
      INNER
      JOIN "projects_sites"
      ON "projects"."id" = "projects_sites"."project_id"
      WHERE "projects"."deleted_at"
      IS
      NULL
      AND "sites"."id" = "projects_sites"."site_id")
      ORDER
      BY "audio_events"."id"
      DESC
    SQL

    a_mod = query.to_sql.gsub(/\s*([A-Z]+)/, "\n\\1").gsub(/(\t| )+/, '').trim('\n')
    b_mod = sql.gsub(/\s*([A-Z]+)/, "\n\\1").gsub(/(\t| )+/, '').trim('\n')
    expect(a_mod).to eq(b_mod)
  end

  it 'excludes deleted projects, sites, audio_recordings, and audio_events from annotation download' do
    user = create(:user, user_name: 'owner user checking excluding deleted items in annotation download')

    # create combinations of deleted and not deleted for project, site, audio_recording, audio_event
    expected_audio_recording = nil
    2.times do |project_n|
      project = create(:project, creator: user)
      project.discard! if project_n == 1

      2.times do |site_n|
        site = create(:site, :with_lat_long, creator: user)
        site.projects << project
        site.save!
        site.discard! if site_n == 1

        2.times do |audio_recording_n|
          audio_recording = create(:audio_recording, :status_ready, creator: user, uploader: user,
            site:)
          audio_recording.discard! if audio_recording_n == 1

          2.times do |audio_event_n|
            audio_event = create(:audio_event, creator: user, audio_recording:)
            audio_event.discard! if audio_event_n == 1
            if project_n == 0 && site_n == 0 && audio_recording_n == 0 && audio_event_n == 0
              expected_audio_recording = audio_event
            end
          end
        end
      end
    end

    # check that AudioEvent.csv_query returns only non-deleted items
    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil)
    query_sql = query.to_sql
    formatted_annotations = AudioEvent.connection.select_all(query_sql)

    # expect(Project.with_discarded.count).to eq(2)
    # expect(Project.count).to eq(1)
    # expect(Project.discarded.count).to eq(1)

    expect(Site.with_discarded.count).to eq(4)
    expect(Site.count).to eq(2)
    expect(Site.discarded.count).to eq(2)

    expect(AudioRecording.with_discarded.count).to eq(8)
    expect(AudioRecording.count).to eq(4)
    expect(AudioRecording.discarded.count).to eq(4)

    expect(AudioEvent.with_discarded.count).to eq(16)
    expect(AudioEvent.count).to eq(8)
    expect(AudioEvent.discarded.count).to eq(8)

    expected_audio_events = [expected_audio_recording.id]
    actual_audio_event_ids = formatted_annotations.pluck('audio_event_id')

    expect(actual_audio_event_ids).to eq(expected_audio_events)
  end

  it 'ensures only one instance of each audio event in annotation download' do
    user = create(:user, user_name: 'owner user checking audio event uniqueness in annotation download')

    # create 2 of everything for project, site, audio_recording, audio_event
    2.times do
      project = create(:project, creator: user)

      2.times do
        site = create(:site, :with_lat_long, creator: user)
        site.projects << project
        site.save!

        2.times do
          audio_recording = create(:audio_recording, :status_ready, creator: user, uploader: user,
            site:)

          create_list(:audio_event, 2, creator: user, audio_recording:)
        end
      end
    end

    # check that AudioEvent.csv_query returns unique audio events
    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil)
    query_sql = query.to_sql
    formatted_annotations = AudioEvent.connection.select_all(query_sql)

    actual_audio_event_ids = formatted_annotations.pluck('audio_event_id')

    expect(actual_audio_event_ids.count).to eq(2 * 2 * 2 * 2)

    expected_audio_event_ids = actual_audio_event_ids.uniq

    expect(actual_audio_event_ids).to eq(expected_audio_event_ids)
  end

  it_behaves_like 'cascade deletes for', :audio_event, {
    taggings: nil,
    comments: nil
  } do
    create_entire_hierarchy
  end
end
