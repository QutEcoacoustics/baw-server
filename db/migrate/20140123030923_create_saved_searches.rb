class CreateSavedSearches < ActiveRecord::Migration
  def change
    create_table :saved_searches do |t|
      t.string :name, :null => false
      t.text    :description
      t.time :start_time
      t.time :end_time
      t.date :start_date
      t.date :end_date
      t.string  :filters
      t.integer :number_of_samples
      t.integer :number_of_tags
      t.string  :types_of_tags
      t.text :tag_text_filters
      t.integer :creator_id, :null => false
      t.integer :updater_id
      t.integer :project_id, :null => false
      t.integer :deleter_id
      t.datetime :deleted_at
      t.timestamps # created_at, updated_at
    end

    # change linking table
    rename_table :datasets_sites, :saved_searches_sites
    rename_column :datasets_sites, :dataset_id, :saved_searches_id

    # drop old datasets table, create from scratch
    drop_table :datasets

    create_table :datasets do |t|
      t.string     :processing_status, :null => false
      t.decimal    :total_duration_seconds,     :precision => 10, :scale => 4
      t.integer    :audio_recording_count

      t.datetime :earliest_datetime
      t.date :earliest_date
      t.time :earliest_time
      t.datetime :latest_datetime
      t.date  :latest_date
      t.time :latest_time
      t.integer :creator_id, :null => false
      t.integer :updater_id
      t.integer :deleter_id
      t.datetime :deleted_at
      t.timestamps # created_at, updated_at
    end
  end
end

=begin
select
min(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00'),
max(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' + CAST(duration_seconds || ' seconds' as interval)),
max(CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' + CAST(duration_seconds || ' seconds' as interval) as date)),
min(CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' as date)),
max(CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' + CAST(duration_seconds || ' seconds' as interval) as time)),
min(CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' as time)),
count(*),
sum(duration_seconds)
FROM audio_recordings ar
WHERE recorded_date >= '2012-11-10' AND recorded_date < '2012-11-16'
;

-- select tags.text, count(*)
-- from audio_events
-- inner join audio_recordings on audio_events.audio_recording_id = audio_recordings.id
-- inner join audio_events_tags on audio_events.id = audio_events_tags.audio_event_id
-- inner join tags on audio_events_tags.tag_id = tags.id
-- WHERE recorded_date >= '2012-01-01' AND recorded_date < '2012-11-15'
-- group by tags.text
-- order by count(*) DESC;

SELECT
recorded_date,
recorded_date AT TIME ZONE 'UTC' ,
recorded_date AT TIME ZONE INTERVAL '+10:00',
recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00',

recorded_date + CAST(duration_seconds || ' seconds' as interval),
CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' as time),
CAST(recorded_date AT TIME ZONE 'UTC' AT TIME ZONE INTERVAL '+10:00' + CAST(duration_seconds || ' seconds' as interval) as time),
recorded_date - date_trunc('day', recorded_date)

FROM audio_recordings ar
WHERE recorded_date >= '2012-11-10' AND recorded_date < '2012-11-16'
order by recorded_date;
=end