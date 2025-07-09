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

  context 'with arel scopes' do
    let!(:audio_recording) {
      create(:audio_recording, recorded_date: Time.zone.parse('2023-10-01 12:00:00'))
    }

    let!(:audio_event) {
      create(:audio_event, start_time_seconds: 123.456, end_time_seconds: 456.789)
    }

    let(:event) {
      AudioEvent
        .joins(:audio_recording)
        .select(AudioEvent.start_date_arel.as('start_date'))
        .where(audio_event_id: audio_event.id)
        .first
    }

    it 'has a start_date arel expression' do
      expect(event.start_date).to eq(Time.zone.parse('2023-10-01 12:02:03.456'))
    end

    it 'has a end_date arel expression' do
      expect(event.end_date).to eq(Time.zone.parse('2023-10-01 12:07:36.789'))
    end
  end

  it 'constructs the expected sql for annotation download (timezone: UTC)' do
    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, nil)
    sql = <<~SQL.squish
      WITH "verification_cte_table"
      AS(
      SELECT "verification_table"."audio_event_id", string_agg(
      CAST("verification_table"."tag_id" as varchar) ||':'|| "tag_text",'|')
      AS "verifications", string_agg(
      CAST("verification_table"."verification_counts" as varchar),'|')
      AS "verification_counts", string_agg(
      CAST("verification_table"."verification_correct" as varchar),'|')
      AS "verification_correct", string_agg(
      CAST("verification_table"."verification_incorrect" as varchar),'|')
      AS "verification_incorrect", string_agg(
      CAST("verification_table"."verification_skip" as varchar),'|')
      AS "verification_skip", string_agg(
      CAST("verification_table"."verification_unsure" as varchar),'|')
      AS "verification_unsure", string_agg("verification_table"."verification_decisions",'|')
      AS "verification_decisions", string_agg(
      CAST("verification_table"."verification_consensus" as varchar),'|')
      AS "verification_consensus"
      FROM(
      SELECT"verification_subquery".*,(
      SELECT label
      FROM(
      VALUES('correct',verification_subquery.verification_correct),('incorrect',verification_subquery.verification_incorrect),('skip',verification_subquery.verification_skip),('unsure',verification_subquery.verification_unsure))
      AS v(label,count)
      ORDER BY count
      DESC
      LIMIT 1)
      AS "verification_decisions",
      ROUND(
      GREATEST ("verification_subquery"."verification_correct","verification_subquery"."verification_incorrect","verification_subquery"."verification_skip","verification_subquery"."verification_unsure")/
      CAST("verification_subquery"."verification_counts"
      AS numeric), 2)
      AS "verification_consensus"
      FROM(
      SELECT "verifications"."audio_event_id","verifications"."tag_id","tags"."text"
      AS "tag_text",
      COUNT("verifications"."confirmed")
      AS "verification_counts",(
      COUNT (*)
      FILTER(
      WHERE "verifications"."confirmed" = 'correct'))
      AS "verification_correct",(
      COUNT(*)
      FILTER(
      WHERE "verifications"."confirmed" = 'incorrect'))
      AS "verification_incorrect",(
      COUNT(*)
      FILTER(
      WHERE "verifications"."confirmed" = 'skip'))
      AS "verification_skip",(
      COUNT(*)
      FILTER(
      WHERE "verifications"."confirmed"='unsure'))
      AS "verification_unsure"
      FROM "verifications"
      INNER
      JOIN "tags"
      ON "verifications"."tag_id" = "tags"."id"
      GROUP BY
      "verifications"."audio_event_id","verifications"."tag_id","tags"."text") "verification_subquery") "verification_table"
      GROUP BY
      "verification_table"."audio_event_id")
      SELECT "audio_events"."id"
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
      AND "projects_sites"."site_id" = "sites"."id") "projects", "regions"."id"
      AS "region_id", "regions"."name"
      AS "region_name", "sites"."id"
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
      IN ('species_name', 'common_name'))) "other_tag_ids","verification_cte_table"."verifications","verification_cte_table"."verification_counts","verification_cte_table"."verification_correct","verification_cte_table"."verification_incorrect","verification_cte_table"."verification_skip","verification_cte_table"."verification_unsure","verification_cte_table"."verification_decisions","verification_cte_table"."verification_consensus", 'http://web/listen/'|| "audio_recordings"."id" || '?start=' || (floor("audio_events"."start_time_seconds" / 30) * 30) || '&end=' || ((floor("audio_events"."start_time_seconds" / 30) * 30) + 30)
      AS "listen_url",'http://web/library/' || "audio_recordings"."id" || '/audio_events/' || audio_events.id
      AS "library_url"
      FROM "audio_events"
      LEFT
      OUTER
      JOIN"verification_cte_table"
      ON"audio_events"."id"="verification_cte_table"."audio_event_id"
      INNER
      JOIN "users"
      ON "users"."id" = "audio_events"."creator_id"
      INNER
      JOIN "audio_recordings"
      ON "audio_recordings"."id" = "audio_events"."audio_recording_id"
      INNER
      JOIN "sites"
      ON "sites"."id" = "audio_recordings"."site_id"
      LEFT OUTER
      JOIN "regions"
      ON "regions"."id" = "sites"."region_id"
      WHERE "audio_events"."deleted_at"
      IS
      NULL
      AND "audio_recordings"."deleted_at"
      IS
      NULL
      AND "sites"."deleted_at"
      IS
      NULL
      AND "regions"."deleted_at"
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
      AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, 'Brisbane')

    sql = <<~SQL.squish
      WITH "verification_cte_table"\n
      AS (\n
      SELECT "verification_table"."audio_event_id", string_agg(
      CAST("verification_table"."tag_id"asvarchar)||':'||"tag_text",'|')
      AS "verifications", string_agg(
      CAST("verification_table"."verification_counts"as varchar),'|')
      AS "verification_counts", string_agg(
      CAST("verification_table"."verification_correct"as varchar),'|')
      AS "verification_correct", string_agg(
      CAST("verification_table"."verification_incorrect"as varchar),'|')
      AS "verification_incorrect", string_agg(
      CAST("verification_table"."verification_skip"as varchar),'|')
      AS "verification_skip", string_agg(
      CAST("verification_table"."verification_unsure"as varchar),'|')
      AS "verification_unsure", string_agg("verification_table"."verification_decisions",'|')
      AS "verification_decisions", string_agg(
      CAST("verification_table"."verification_consensus"as varchar),'|')
      AS "verification_consensus"
      FROM(
      SELECT"verification_subquery".*,(
      SELECT label
      FROM(
      VALUES('correct',verification_subquery.verification_correct),('incorrect',verification_subquery.verification_incorrect),('skip',verification_subquery.verification_skip),('unsure',verification_subquery.verification_unsure))
      AS v(label,count)
      ORDER BY count
      DESC
      LIMIT 1)
      AS "verification_decisions",
      ROUND(
      GREATEST ("verification_subquery"."verification_correct","verification_subquery"."verification_incorrect","verification_subquery"."verification_skip","verification_subquery"."verification_unsure")/
      CAST("verification_subquery"."verification_counts"
      AS numeric), 2)
      AS "verification_consensus"
      FROM(
      SELECT "verifications"."audio_event_id","verifications"."tag_id","tags"."text"
      AS "tag_text",
      COUNT("verifications"."confirmed")
      AS "verification_counts",(
      COUNT (*)
      FILTER(
      WHERE "verifications"."confirmed" = 'correct'))
      AS "verification_correct",(
      COUNT(*)
      FILTER(
      WHERE "verifications"."confirmed" = 'incorrect'))
      AS "verification_incorrect",(
      COUNT(*)
      FILTER(
      WHERE "verifications"."confirmed" = 'skip'))
      AS "verification_skip",(
      COUNT(*)
      FILTER(
      WHERE "verifications"."confirmed"='unsure'))
      AS"verification_unsure"
      FROM"verifications"
      INNER
      JOIN"tags"
      ON"verifications"."tag_id"="tags"."id"
      GROUP
      BY"verifications"."audio_event_id","verifications"."tag_id","tags"."text")"verification_subquery")"verification_table"
      GROUP
      BY"verification_table"."audio_event_id")
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
      AND "projects_sites"."site_id" = "sites"."id") "projects", "regions"."id"
      AS "region_id", "regions"."name"
      AS "region_name", "sites"."id"
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
      IN ('species_name', 'common_name'))) "other_tag_ids","verification_cte_table"."verifications","verification_cte_table"."verification_counts","verification_cte_table"."verification_correct","verification_cte_table"."verification_incorrect","verification_cte_table"."verification_skip","verification_cte_table"."verification_unsure","verification_cte_table"."verification_decisions","verification_cte_table"."verification_consensus", 'http://web/listen/'|| "audio_recordings"."id" || '?start=' || (floor("audio_events"."start_time_seconds" / 30) * 30) || '&end=' || ((floor("audio_events"."start_time_seconds" / 30) * 30) + 30)
      AS "listen_url",'http://web/library/' || "audio_recordings"."id" || '/audio_events/' || audio_events.id
      AS "library_url"
      FROM "audio_events"
      LEFT
      OUTER
      JOIN"verification_cte_table"
      ON"audio_events"."id"="verification_cte_table"."audio_event_id"
      INNER
      JOIN "users"
      ON "users"."id" = "audio_events"."creator_id"
      INNER
      JOIN "audio_recordings"
      ON "audio_recordings"."id" = "audio_events"."audio_recording_id"
      INNER
      JOIN "sites"
      ON "sites"."id" = "audio_recordings"."site_id"
      LEFT OUTER
      JOIN "regions"
      ON "regions"."id" = "sites"."region_id"
      WHERE "audio_events"."deleted_at"
      IS
      NULL
      AND "audio_recordings"."deleted_at"
      IS
      NULL
      AND "sites"."deleted_at"
      IS
      NULL
      AND "regions"."deleted_at"
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
    AudioEvent.delete_all
    user = create(:user, user_name: 'owner user checking excluding deleted items in annotation download')

    # create combinations of deleted and not deleted for project, site, audio_recording, audio_event
    expected_audio_event = nil
    2.times do |project_n|
      project = create(:project, creator: user)
      project.discard! if project_n == 1

      region = create(:region, creator: user, project: project)
      region.discard! if project_n == 1
      2.times do |site_n|
        site = create(:site, :with_lat_long, creator: user, projects: [project], region:)

        site.discard! if site_n == 1

        2.times do |audio_recording_n|
          audio_recording = create(:audio_recording, :status_ready, creator: user, uploader: user,
            site:)
          audio_recording.discard! if audio_recording_n == 1

          2.times do |audio_event_n|
            audio_event = create(:audio_event, creator: user, audio_recording:)
            audio_event.discard! if audio_event_n == 1
            if project_n == 0 && site_n == 0 && audio_recording_n == 0 && audio_event_n == 0
              expected_audio_event = audio_event
            end
          end
        end
      end
    end

    # check that AudioEvent.csv_query returns only non-deleted items
    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, nil)
    query_sql = query.to_sql
    formatted_annotations = AudioEvent.connection.select_all(query_sql)

    expect(Project.with_discarded.count).to eq(2)
    expect(Project.count).to eq(1)
    expect(Project.discarded.count).to eq(1)

    expect(Region.with_discarded.count).to eq(2)
    expect(Region.count).to eq(1)
    expect(Region.discarded.count).to eq(1)

    expect(Site.with_discarded.count).to eq(4)
    expect(Site.count).to eq(2)
    expect(Site.discarded.count).to eq(2)

    expect(AudioRecording.with_discarded.count).to eq(8)
    expect(AudioRecording.count).to eq(4)
    expect(AudioRecording.discarded.count).to eq(4)

    expect(AudioEvent.with_discarded.count).to eq(16)
    expect(AudioEvent.count).to eq(8)
    expect(AudioEvent.discarded.count).to eq(8)

    expected_audio_events = [expected_audio_event.id]
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
    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, nil)
    query_sql = query.to_sql
    formatted_annotations = AudioEvent.connection.select_all(query_sql)

    actual_audio_event_ids = formatted_annotations.pluck('audio_event_id')

    expect(actual_audio_event_ids.count).to eq(2 * 2 * 2 * 2)

    expected_audio_event_ids = actual_audio_event_ids.uniq

    expect(actual_audio_event_ids).to eq(expected_audio_event_ids)
  end

  it 'includes events from sites that have no region in annotation download' do
    user = create(:user)
    other_site = create(:site, region: nil, creator: user)
    other_audio_recording = create(:audio_recording, site: other_site, creator: user)
    other_audio_event = create(:audio_event, audio_recording: other_audio_recording, creator: user)

    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil, nil).to_sql
    returned_event_ids = AudioEvent.connection.select_all(query).pluck('audio_event_id')

    expect(returned_event_ids).to eq([other_audio_event.id])
  end

  describe 'verifications query for annotation downloads' do
    create_entire_hierarchy

    # set up a new event, with two tags and taggings
    let(:event_one) { create(:audio_event, creator: writer_user, audio_recording:) }

    let(:tag_one) { create(:tag_taxonomic_true_common, creator: writer_user) }
    let(:tag_two) { create(:tag_taxonomic_true_common, creator: writer_user) }

    let(:tagging_one) {
      create(:tagging,
        audio_event_id: event_one.id,
        tag_id: tag_one.id,
        creator: writer_user)
    }
    let(:tagging_two) {
      create(:tagging,
        audio_event_id: event_one.id,
        tag_id: tag_two.id,
        creator: writer_user)
    }

    # the number of verifications to create for each `confirmed` value, for each tag
    let(:choices_one) {
      { Verification::CONFIRMATION_TRUE => 4,
        Verification::CONFIRMATION_FALSE => 3,
        Verification::CONFIRMATION_SKIP => 2,
        Verification::CONFIRMATION_UNSURE => 1 }
    }
    let(:choices_two) {
      { Verification::CONFIRMATION_TRUE => 1,
        Verification::CONFIRMATION_FALSE => 4,
        Verification::CONFIRMATION_SKIP => 3,
        Verification::CONFIRMATION_UNSURE => 2 }
    }

    # for the single audio_event `event_one`, with two tags / annotations:
    # create 10 verifications of tag one, and 10 verifications of tag two
    # each verification coming from a different user
    before do
      event_verifications_for_tagging(tagging_one, choices_one)
      event_verifications_for_tagging(tagging_two, choices_two)
    end

    it 'aggregates verifications from multiple tags correctly' do
      verification_cte_table, query_cte = AudioEvent.verification_summary_cte

      query = AudioEvent.arel_table.join(verification_cte_table)
        .on(AudioEvent.arel_table[:id].eq(verification_cte_table[:audio_event_id]))
        .project(verification_cte_table[Arel.star])
        .with(query_cte)

      results = AudioEvent.connection.select_all(query.to_sql)

      expect(results.pluck('verifications')).to eq([
        "#{tag.id}:#{tag.text}",
        "#{tag_one.id}:#{tag_one.text}|#{tag_two.id}:#{tag_two.text}"
      ])

      expect(results.pluck('verification_counts')).to eq([
        audio_event.verifications.count.to_s,
        [event_one.verifications.where(tag: tag_one.id).count.to_s,
         event_one.verifications.where(tag: tag_two.id).count.to_s].join('|')
      ])

      [
        Verification::CONFIRMATION_TRUE,
        Verification::CONFIRMATION_FALSE,
        Verification::CONFIRMATION_SKIP,
        Verification::CONFIRMATION_UNSURE
      ].each do |value|
        eq([audio_event.verifications.where(confirmed: value).count.to_s,
            [event_one.verifications.where(tag: tag_one.id, confirmed: value).count,
             event_one.verifications.where(tag: tag_two.id, confirmed: value).count].map(&:to_s).join('|')])
      end

      expect(results.pluck('verification_decisions')).to eq([
        verification.confirmed,
        [choices_one.max_by { |_k, v| v }.first,
         choices_two.max_by { |_k, v| v }.first].join('|')
      ])

      expect(results.pluck('verification_consensus')).to eq([
        '1.00',
        [format('%.2f', choices_one.values.max / choices_one.values.sum.to_f),
         format('%.2f', choices_two.values.max / choices_two.values.sum.to_f)].join('|')
      ])
    end
  end

  it_behaves_like 'cascade deletes for', :audio_event, {
    taggings: nil,
    comments: nil,
    verifications: nil
  } do
    create_entire_hierarchy
  end
end

def event_verifications_for_tagging(tagging, choices)
  choices.each do |choice, number|
    number.times do |_i|
      create(:verification,
        audio_event_id: tagging.audio_event_id,
        tag_id: tagging.tag_id,
        creator: create(:user),
        confirmed: choice)
    end
  end
end
