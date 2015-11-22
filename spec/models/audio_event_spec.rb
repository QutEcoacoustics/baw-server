require 'rails_helper'

describe AudioEvent, :type => :model do
  subject { FactoryGirl.build(:audio_event) }
  it 'has a valid factory' do
    expect(FactoryGirl.create(:audio_event)).to be_valid
  end
  it 'can have a blank end time' do
    ae = FactoryGirl.build(:audio_event, :end_time_seconds => nil)
    expect(ae).to be_valid
  end
  it 'can have a blank high frequency' do
    expect(FactoryGirl.build(:audio_event, :high_frequency_hertz => nil)).to be_valid
  end
  it 'can have a blank end time and  a blank high frequency' do
    expect(FactoryGirl.build(:audio_event, {:end_time_seconds => nil, :high_frequency_hertz => nil})).to be_valid
  end

  it { is_expected.to belong_to(:audio_recording) }
  it { is_expected.to belong_to(:creator).with_foreign_key(:creator_id) }
  it { is_expected.to belong_to(:updater).with_foreign_key(:updater_id) }
  it { is_expected.to belong_to(:deleter).with_foreign_key(:deleter_id) }

  it { is_expected.to have_many(:tags) }
  it { is_expected.to accept_nested_attributes_for(:tags) }

  it { is_expected.to validate_inclusion_of(:is_reference).in_array([true, false]) }

  it { is_expected.to validate_presence_of(:start_time_seconds) }
  it { is_expected.to validate_numericality_of(:start_time_seconds).is_greater_than_or_equal_to(0) }

  it { is_expected.to validate_numericality_of(:end_time_seconds).is_greater_than_or_equal_to(0).allow_nil }

  it { is_expected.to validate_presence_of(:low_frequency_hertz) }
  it { is_expected.to validate_numericality_of(:low_frequency_hertz).is_greater_than_or_equal_to(0) }

  it { is_expected.to validate_numericality_of(:high_frequency_hertz).is_greater_than_or_equal_to(0).allow_nil }

  it 'is invalid if the end time is less than the start time' do
    expect(build(:audio_event, {start_time_seconds: 100.320, end_time_seconds: 10.360})).not_to be_valid
  end

  it 'is invalid if the end frequency is less then the low frequency' do
    expect(build(:audio_event, {low_frequency_hertz: 1000, high_frequency_hertz: 100})).not_to be_valid
  end

  it 'constructs the expected sql for annotation download (timezone: UTC)' do

    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, nil)

    sql = <<-eos
SELECT
"audio_events"."id" AS audio_event_id,
"audio_recordings"."id" AS audio_recording_id,
"audio_recordings"."uuid" AS audio_recording_uuid,
to_char("audio_recordings"."recorded_date" + INTERVAL '0 seconds', 'YYYY-MM-DD') AS audio_recording_start_date_utc_00_00,
to_char("audio_recordings"."recorded_date" + INTERVAL '0 seconds', 'HH24:MI:SS') AS audio_recording_start_time_utc_00_00,
to_char("audio_recordings"."recorded_date" + INTERVAL '0 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS audio_recording_start_datetime_utc_00_00,
to_char("audio_events"."created_at" + INTERVAL '0 seconds', 'YYYY-MM-DD') AS event_created_at_date_utc_00_00,
to_char("audio_events"."created_at" + INTERVAL '0 seconds', 'HH24:MI:SS') AS event_created_at_time_utc_00_00,
to_char("audio_events"."created_at" + INTERVAL '0 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS event_created_at_datetime_utc_00_00,
(SELECT string_agg(CAST("projects"."id" as varchar) || ':' || "projects"."name", '|') FROM "projects_sites" INNER JOIN "projects" ON "projects"."id" = "projects_sites"."project_id" WHERE "projects_sites"."site_id" = "sites"."id") projects,
"sites"."id" AS site_id, "sites"."name" AS site_name,
to_char("audio_recordings"."recorded_date" + CAST("audio_events"."start_time_seconds" || ' seconds' as interval) + INTERVAL '0 seconds', 'YYYY-MM-DD') AS event_start_date_utc_00_00,
to_char("audio_recordings"."recorded_date" + CAST("audio_events"."start_time_seconds" || ' seconds' as interval) + INTERVAL '0 seconds', 'HH24:MI:SS') AS event_start_time_utc_00_00,
to_char("audio_recordings"."recorded_date" + CAST("audio_events"."start_time_seconds" || ' seconds' as interval) + INTERVAL '0 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS event_start_datetime_utc_00_00,
"audio_events"."start_time_seconds" AS event_start_seconds,
"audio_events"."end_time_seconds" AS event_end_seconds,
"audio_events"."end_time_seconds" - "audio_events"."start_time_seconds" AS event_duration_seconds,
"audio_events"."low_frequency_hertz" AS low_frequency_hertz,
"audio_events"."high_frequency_hertz" AS high_frequency_hertz,
"audio_events"."is_reference" AS is_reference,
"audio_events"."creator_id" AS created_by, "audio_events"."updater_id" AS updated_by,
(SELECT string_agg(CAST("tags"."id" as varchar) || ':' || "tags"."text", '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND "tags"."type_of_tag" = 'common_name') common_name_tags,
(SELECT string_agg(CAST("tags"."id" as varchar), '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND "tags"."type_of_tag" = 'common_name') common_name_tag_ids,
(SELECT string_agg(CAST("tags"."id" as varchar) || ':' || "tags"."text", '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND "tags"."type_of_tag" = 'species_name') species_name_tags,
(SELECT string_agg(CAST("tags"."id" as varchar), '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND "tags"."type_of_tag" = 'species_name') species_name_tag_ids,
(SELECT string_agg(CAST("tags"."id" as varchar) || ':' || "tags"."text" || ':' || "tags"."type_of_tag", '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND NOT ("tags"."type_of_tag" IN ('species_name', 'common_name'))) other_tags,
(SELECT string_agg(CAST("tags"."id" as varchar), '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND NOT ("tags"."type_of_tag" IN ('species_name', 'common_name'))) other_tag_ids,
'http://localhost/listen/'|| "audio_recordings"."id" || '?start=' || (floor("audio_events"."start_time_seconds" / 30) * 30) || '&end=' || ((floor("audio_events"."start_time_seconds" / 30) * 30) + 30) AS listen_url,
'http://localhost/library/' || "audio_recordings"."id" || '/audio_events/' || audio_events.id AS library_url
FROM "audio_events"
INNER JOIN "users" ON "users"."id" = "audio_events"."creator_id"
INNER JOIN "audio_recordings" ON "audio_recordings"."id" = "audio_events"."audio_recording_id"
INNER JOIN "sites" ON "sites"."id" = "audio_recordings"."site_id"
 ORDER BY "audio_events"."id" DESC
    eos

    expect(query.to_sql).to eq(sql.gsub("\n", ' ').trim(' ', ''))

  end

  it 'constructs the expected sql for annotation download (timezone: Brisbane)' do

    query = AudioEvent.csv_query(nil, nil, nil, nil, nil, nil, 'Brisbane')

    sql = <<-eos
SELECT
"audio_events"."id" AS audio_event_id,
"audio_recordings"."id" AS audio_recording_id,
"audio_recordings"."uuid" AS audio_recording_uuid,
to_char("audio_recordings"."recorded_date" + INTERVAL '36000 seconds', 'YYYY-MM-DD') AS audio_recording_start_date_brisbane_10_00,
to_char("audio_recordings"."recorded_date" + INTERVAL '36000 seconds', 'HH24:MI:SS') AS audio_recording_start_time_brisbane_10_00,
to_char("audio_recordings"."recorded_date" + INTERVAL '36000 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"+10:00"') AS audio_recording_start_datetime_brisbane_10_00,
to_char("audio_events"."created_at" + INTERVAL '36000 seconds', 'YYYY-MM-DD') AS event_created_at_date_brisbane_10_00,
to_char("audio_events"."created_at" + INTERVAL '36000 seconds', 'HH24:MI:SS') AS event_created_at_time_brisbane_10_00,
to_char("audio_events"."created_at" + INTERVAL '36000 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"+10:00"') AS event_created_at_datetime_brisbane_10_00,
(SELECT string_agg(CAST("projects"."id" as varchar) || ':' || "projects"."name", '|') FROM "projects_sites" INNER JOIN "projects" ON "projects"."id" = "projects_sites"."project_id" WHERE "projects_sites"."site_id" = "sites"."id") projects,
"sites"."id" AS site_id, "sites"."name" AS site_name,
to_char("audio_recordings"."recorded_date" + CAST("audio_events"."start_time_seconds" || ' seconds' as interval) + INTERVAL '36000 seconds', 'YYYY-MM-DD') AS event_start_date_brisbane_10_00,
to_char("audio_recordings"."recorded_date" + CAST("audio_events"."start_time_seconds" || ' seconds' as interval) + INTERVAL '36000 seconds', 'HH24:MI:SS') AS event_start_time_brisbane_10_00,
to_char("audio_recordings"."recorded_date" + CAST("audio_events"."start_time_seconds" || ' seconds' as interval) + INTERVAL '36000 seconds', 'YYYY-MM-DD"T"HH24:MI:SS"+10:00"') AS event_start_datetime_brisbane_10_00,
"audio_events"."start_time_seconds" AS event_start_seconds,
"audio_events"."end_time_seconds" AS event_end_seconds,
"audio_events"."end_time_seconds" - "audio_events"."start_time_seconds" AS event_duration_seconds,
"audio_events"."low_frequency_hertz" AS low_frequency_hertz,
"audio_events"."high_frequency_hertz" AS high_frequency_hertz,
"audio_events"."is_reference" AS is_reference,
"audio_events"."creator_id" AS created_by, "audio_events"."updater_id" AS updated_by,
(SELECT string_agg(CAST("tags"."id" as varchar) || ':' || "tags"."text", '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND "tags"."type_of_tag" = 'common_name') common_name_tags,
(SELECT string_agg(CAST("tags"."id" as varchar), '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND "tags"."type_of_tag" = 'common_name') common_name_tag_ids,
(SELECT string_agg(CAST("tags"."id" as varchar) || ':' || "tags"."text", '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND "tags"."type_of_tag" = 'species_name') species_name_tags,
(SELECT string_agg(CAST("tags"."id" as varchar), '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND "tags"."type_of_tag" = 'species_name') species_name_tag_ids,
(SELECT string_agg(CAST("tags"."id" as varchar) || ':' || "tags"."text" || ':' || "tags"."type_of_tag", '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND NOT ("tags"."type_of_tag" IN ('species_name', 'common_name'))) other_tags,
(SELECT string_agg(CAST("tags"."id" as varchar), '|') FROM "tags" INNER JOIN "audio_events_tags" ON "audio_events_tags"."tag_id" = "tags"."id" WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id" AND NOT ("tags"."type_of_tag" IN ('species_name', 'common_name'))) other_tag_ids,
'http://localhost/listen/'|| "audio_recordings"."id" || '?start=' || (floor("audio_events"."start_time_seconds" / 30) * 30) || '&end=' || ((floor("audio_events"."start_time_seconds" / 30) * 30) + 30) AS listen_url,
'http://localhost/library/' || "audio_recordings"."id" || '/audio_events/' || audio_events.id AS library_url
FROM "audio_events"
INNER JOIN "users" ON "users"."id" = "audio_events"."creator_id"
INNER JOIN "audio_recordings" ON "audio_recordings"."id" = "audio_events"."audio_recording_id"
INNER JOIN "sites" ON "sites"."id" = "audio_recordings"."site_id"
 ORDER BY "audio_events"."id" DESC
    eos

    expect(query.to_sql).to eq(sql.gsub("\n", ' ').trim(' ', ''))

  end

end