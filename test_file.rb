# frozen_string_literal: true

require 'factory_bot'
# FactoryBot.find_definitions

module TestDataSetup
  include FactoryBot::Syntax::Methods

  # FactoryBot.create a recording with default values from current scope
  # yield the recording to a block or else return it
  def self.with_recording(site:, creator:, date:)
    recording = FactoryBot.create(:audio_recording, site: site, creator: creator, recorded_date: date)
    block_given? ? yield(recording) : recording
  end

  # FactoryBot.create event with default values from current scope
  # @param [Hash] args optional arguments for creating verifications
  # @option [Array<String>] :confirmations verification confirmation values
  # @option [Array<User>] :users to confirm the event, length >= confirmations
  # @return the audio_recording used to FactoryBot.create the event
  def self.with_event(creator:, provenance:, recording:, start: 5, tag: tags.values.first, **args)
    FactoryBot.create(:audio_event_tagging, audio_recording: recording, creator: creator,
      start_time_seconds: start, provenance: provenance, tag:, **args)
    recording
  end

  def self.create_complex_audio_data
    # Your complex factory setup here
    users = []
    4.times { users << FactoryBot.create(:user) }
    creator = users.first
    provenance = FactoryBot.create(:provenance, creator: creator)
    start_date_string = '2025-01-01T00:00:00Z'
    start_date = DateTime.parse(start_date_string, nil)
    tag_keys = [:koala, :whip_bird, :honeyeater, :magpie]
    tags = tag_keys.index_with { |tag_name| FactoryBot.create(:tag, text: tag_name) }

    project = FactoryBot.create(:project, creator: creator)
    region = FactoryBot.create(:region, project: project, creator: creator)
    site_one = FactoryBot.create(:site_with_lat_long, projects: [project], region: region, creator: creator)
    site_two = FactoryBot.create(:site_with_lat_long, projects: [project], region: region, creator: creator)
    data =
      { project: project,
        sites: [site_one, site_two],
        recordings: [
          with_recording(site: site_one, creator: creator, date: start_date) { |recording|
            with_event(creator: creator, provenance: provenance, recording:, start: 5, tag: tags[:koala])
            with_event(creator: creator, provenance: provenance, recording:, start: 3600, tag: tags[:koala])
            with_event(creator: creator, provenance: provenance, recording:, start: 7600, tag: tags[:whip_bird],
              confirmations: ['correct', 'correct'], users: users)
          },
          with_recording(site: site_two, creator: creator, date: start_date + 2.days) { |recording|
            with_event(creator: creator, provenance: provenance, recording:, start: 5, tag: tags[:koala])
          },
          with_recording(site: site_one, creator: creator, date: start_date + 2.days) { |recording|
            with_event(creator: creator, provenance: provenance, recording:, start: 18_000, tag: tags[:koala])
            with_event(creator: creator, provenance: provenance, recording:, start: 20_000, tag: tags[:koala],
              confirmations: ['correct', 'correct', 'correct', 'incorrect'], users: users)
          },
          with_recording(site: site_one, creator: creator, date: start_date + 6.days) { |recording|
            with_event(creator: creator, provenance: provenance, recording:, start: 5, tag: tags[:koala])
            with_event(creator: creator, provenance: provenance, recording:, start: 3600, tag: tags[:whip_bird],
              confirmations: ['incorrect', 'incorrect'], users: users) # whip bird should have average of 1 consensus; verifiers are always in agreement
            with_event(creator: creator, provenance: provenance, recording:, start: 7600, tag: tags[:honeyeater])
            with_event(creator: creator, provenance: provenance, recording:, start: 18_000, tag: tags[:magpie],
              confirmations: ['correct', 'incorrect', 'incorrect'], users: users)
          }
        ] }

    default_filter =
      {
        filter: {},
        options: {
          bucket_size: 'day',
          start_time: start_date,
          end_time: start_date + 7.days
        }
      }

    # make an extra tagging on the last event NOTE the tag is doing to be random
    FactoryBot.create(:tagging, audio_event: AudioEvent.last)

    # return one big hash
    {
      users: users,
      creator: creator,
      start_date: start_date,
      end_date: start_date + 7.days,
      tags: tags,
      project: project,
      region: region,
      site_one: site_one,
      site_two: site_two,
      data: data,
      default_filter: default_filter
    }
  end

  # base cte for audio event report with permissions stuff removed
  def self.base_cte
    Arel.sql(
      <<~SQL.squish
          (SELECT
           "audio_events"."id",
           "audio_events"."audio_recording_id",
           "audio_events"."start_time_seconds",
           "audio_events"."end_time_seconds",
           "audio_events"."low_frequency_hertz",
           "audio_events"."high_frequency_hertz",
           "audio_events"."is_reference",
           "audio_events"."creator_id",
           "audio_events"."updated_at",
           "audio_events"."created_at",
           "audio_events"."audio_event_import_file_id",
           "audio_events"."import_file_index",
           "audio_events"."provenance_id",
           "audio_events"."channel",
           "audio_events_tags"."id" AS "tagging_ids",
           "sites"."id" AS "site_ids",
           "regions"."id" AS "region_ids",
           "tags"."id" AS "tag_id",
           "audio_events"."audio_recording_id" AS "audio_recording_ids",
           "audio_events"."provenance_id" AS "provenance_ids",
           "audio_events"."score" AS "score",
           "audio_events"."id" AS "audio_event_id",
           "audio_recordings"."recorded_date",
           audio_recordings.recorded_date + CAST(audio_events.start_time_seconds || ' seconds' as interval) as start_time_absolute,
           audio_recordings.recorded_date + CAST(audio_events.end_time_seconds || ' seconds' as interval) as end_time_absolute
         FROM "audio_events"
         INNER JOIN "audio_recordings" ON
           ("audio_recordings"."deleted_at" IS NULL) AND
           ("audio_recordings"."id" = "audio_events"."audio_recording_id")
         INNER JOIN "sites" ON
           ("sites"."deleted_at" IS NULL) AND
           ("sites"."id" = "audio_recordings"."site_id")
         INNER JOIN "audio_events_tags" ON
           "audio_events"."id" = "audio_events_tags"."audio_event_id"
         INNER JOIN "tags" ON
           "audio_events_tags"."tag_id" = "tags"."id"
         LEFT OUTER JOIN "regions" ON
           "regions"."id" = "sites"."region_id"
        )
      SQL
    )
  end

  def self.base_cte_init
    base_cte = TestDataSetup.base_cte
    base_table = rel::Table.new('base_table')
    arel_base_cte = Arel::Nodes::As.new(base_cte, Arel::Table.new(base_table))
    [arel_base_cte, base_table]
  end

  def self.final_query
    Arel.sql(
          <<~SQL.squish
            WITH "base_table" AS (SELECT "audio_events"."id",
            "audio_events"."audio_recording_id",
            "audio_events"."start_time_seconds",
            "audio_events"."end_time_seconds",
            "audio_events"."low_frequency_hertz",
            "audio_events"."high_frequency_hertz",
            "audio_events"."is_reference", "audio_events"."creator_id",
            "audio_events"."updated_at", "audio_events"."created_at",
            "audio_events"."audio_event_import_file_id",
            "audio_events"."import_file_index", "audio_events"."provenance_id",
            "audio_events"."channel", "audio_events_tags"."id" AS "tagging_ids",
            "sites"."id" AS "site_ids", "regions"."id" AS "region_ids",
            "tags"."id" AS "tag_id", "audio_events"."audio_recording_id" AS
            "audio_recording_ids", "audio_events"."provenance_id" AS
            "provenance_ids", "audio_events"."score" AS "score",
            "audio_events"."id" AS "audio_event_id",
            "audio_recordings"."recorded_date", audio_recordings.recorded_date +
            CAST(audio_events.start_time_seconds || ' seconds' as interval) as
            start_time_absolute, audio_recordings.recorded_date +
            CAST(audio_events.end_time_seconds || ' seconds' as interval) as
            end_time_absolute FROM "audio_events" INNER JOIN "audio_recordings"
            ON ("audio_recordings"."deleted_at" IS NULL) AND
            ("audio_recordings"."id" = "audio_events"."audio_recording_id")
            INNER JOIN "sites" ON ("sites"."deleted_at" IS NULL) AND
            ("sites"."id" = "audio_recordings"."site_id") INNER JOIN
            "audio_events_tags" ON "audio_events"."id" =
            "audio_events_tags"."audio_event_id" INNER JOIN "tags" ON
            "audio_events_tags"."tag_id" = "tags"."id" LEFT OUTER JOIN "regions"
            ON "regions"."id" = "sites"."region_id" WHERE
            ("audio_events"."deleted_at" IS NULL) AND ((EXISTS (SELECT 1 FROM
            "projects_sites" INNER JOIN "projects" ON
            "projects_sites"."project_id" = "projects"."id" WHERE
            "projects_sites"."site_id" = "sites"."id" AND EXISTS (SELECT 1 FROM
            "permissions" WHERE "permissions"."level" IN ('owner', 'writer',
            'reader') AND "projects"."id" = "permissions"."project_id" AND
            "projects"."deleted_at" IS NULL AND (("permissions"."user_id" = 3)
            OR ("permissions"."allow_logged_in" = TRUE))))) OR (EXISTS (SELECT 1
            FROM "audio_events" "ae_ref" WHERE "ae_ref"."deleted_at" IS NULL AND
            "ae_ref"."is_reference" = TRUE AND "ae_ref"."id" =
            "audio_events"."id")))), "time_range_and_interval" AS (SELECT
            tsrange(CAST('2025-01-01 00:00:00' AS timestamp without time zone),
            CAST('2025-01-08 00:00:00' AS timestamp without time zone), '[)') AS
            "time_range", INTERVAL '1 day' AS "bucket_interval"),
            "number_of_buckets" AS (SELECT
            "time_range_and_interval"."time_range",
            "time_range_and_interval"."bucket_interval", (SELECT (EXTRACT(EPOCH
            FROM upper("time_range_and_interval"."time_range")) - EXTRACT(EPOCH
            FROM LOWER("time_range_and_interval"."time_range"))) / EXTRACT(EPOCH
            FROM "time_range_and_interval"."bucket_interval") FROM
            "time_range_and_interval") "bucket_count" FROM
            "time_range_and_interval"), "bucketed_time_series" AS (SELECT
            bucket_number, tsrange(lower(time_range) + ((bucket_number - 1) *
            bucket_interval), lower(time_range) + (bucket_number *
            bucket_interval)) AS "time_bucket" FROM "number_of_buckets" CROSS
            JOIN generate_series(1, CEIL("number_of_buckets"."bucket_count")) AS
            bucket_number), "data_with_allocated_bucket" AS (SELECT
            width_bucket(EXTRACT(EPOCH FROM "base_table"."start_time_absolute"),
            (SELECT EXTRACT(EPOCH FROM LOWER("number_of_buckets"."time_range"))
            FROM "number_of_buckets"), (SELECT EXTRACT(EPOCH FROM
            upper("number_of_buckets"."time_range")) FROM "number_of_buckets"),
            (SELECT CAST(CEIL("number_of_buckets"."bucket_count") AS int) FROM
            "number_of_buckets")) AS "bucket", "base_table"."tag_id",
            "base_table"."score" FROM "base_table"), "tag_first_appearance" AS
            (SELECT "data_with_allocated_bucket"."bucket",
            "data_with_allocated_bucket"."tag_id",
            "data_with_allocated_bucket"."score", CASE WHEN row_number() OVER
            (PARTITION BY "data_with_allocated_bucket"."tag_id" ORDER BY
            "data_with_allocated_bucket"."bucket") = 1 THEN 1 ELSE 0 END AS
            "is_first_time" FROM "data_with_allocated_bucket" WHERE
            "data_with_allocated_bucket"."bucket" IS NOT NULL), "sum_groups" AS
            (SELECT SUM("tag_first_appearance"."is_first_time") AS
            "sum_new_tags", "tag_first_appearance"."bucket" FROM
            "tag_first_appearance" GROUP BY "tag_first_appearance"."bucket"),
            "cumulative_unique_tag_series" AS (SELECT
            "bucketed_time_series"."bucket_number",
            "bucketed_time_series"."time_bucket" AS "range",
            CAST(COALESCE(SUM("sum_groups"."sum_new_tags") OVER (ORDER BY
            "bucketed_time_series"."bucket_number"), 0) AS int) AS "count" FROM
            "bucketed_time_series" LEFT OUTER JOIN "sum_groups" ON
            "bucketed_time_series"."bucket_number" = "sum_groups"."bucket"),
            "verification_base" AS (SELECT "base_table"."audio_event_id",
            "base_table"."tag_id", "base_table"."provenance_id",
            "base_table"."score", "verifications"."id" AS "verification_id",
            "verifications"."confirmed" FROM "base_table" LEFT OUTER JOIN
            "verifications" ON ("base_table"."audio_event_id" =
            "verifications"."audio_event_id") AND ("base_table"."tag_id" =
            "verifications"."tag_id")), "verification_counts" AS (SELECT
            "verification_base"."tag_id", "verification_base"."provenance_id",
            "verification_base"."audio_event_id",
            "verification_base"."confirmed",
            COUNT("verification_base"."verification_id") AS "category_count",
            CAST(COALESCE(COUNT("verification_base"."verification_id"), 0) AS
            float) /
            NULLIF(COALESCE(SUM(COUNT("verification_base"."verification_id"))
            OVER (PARTITION BY "verification_base"."tag_id",
            "verification_base"."provenance_id",
            "verification_base"."audio_event_id"), 0), 0) AS "ratio" FROM
            "verification_base" GROUP BY "verification_base"."tag_id",
            "verification_base"."provenance_id",
            "verification_base"."audio_event_id",
            "verification_base"."confirmed"),
            "verification_counts_per_tag_provenance_event" AS (SELECT
            "verification_counts"."tag_id",
            "verification_counts"."provenance_id",
            "verification_counts"."audio_event_id",
            MAX("verification_counts"."ratio") AS "consensus_for_event",
            SUM("verification_counts"."category_count") AS
            "total_verifications_for_event" FROM "verification_counts" GROUP BY
            "verification_counts"."tag_id",
            "verification_counts"."provenance_id",
            "verification_counts"."audio_event_id"),
            "verification_counts_per_tag_provenance" AS (SELECT
            "verification_counts_per_tag_provenance_event"."tag_id",
            "verification_counts_per_tag_provenance_event"."provenance_id",
            COUNT("verification_counts_per_tag_provenance_event"."audio_event_id")
            AS "count",
            AVG("verification_counts_per_tag_provenance_event"."consensus_for_event")
            AS "consensus",
            SUM("verification_counts_per_tag_provenance_event"."total_verifications_for_event")
            AS "verifications" FROM
            "verification_counts_per_tag_provenance_event" GROUP BY
            "verification_counts_per_tag_provenance_event"."tag_id",
            "verification_counts_per_tag_provenance_event"."provenance_id"),
            "event_summaries" AS (SELECT
            "verification_counts_per_tag_provenance"."provenance_id",
            "verification_counts_per_tag_provenance"."tag_id",
            jsonb_agg(jsonb_build_object('count',
            "verification_counts_per_tag_provenance"."count", 'verifications',
            "verification_counts_per_tag_provenance"."verifications",
            'consensus', "verification_counts_per_tag_provenance"."consensus"))
            AS "events" FROM "verification_counts_per_tag_provenance" GROUP BY
            "verification_counts_per_tag_provenance"."tag_id",
            "verification_counts_per_tag_provenance"."provenance_id"),
            "composition_series" AS (SELECT
            "bucketed_time_series"."bucket_number",
            "bucketed_time_series"."time_bucket" AS "range",
            distinct_tags.tag_id, COUNT(DISTINCT "base_table"."audio_event_id")
            AS "count", (SUM(COUNT(DISTINCT "base_table"."audio_event_id")) OVER
            (PARTITION BY "bucketed_time_series"."bucket_number")) AS
            "total_tags_in_bin", COUNT("verification_base"."verification_id") AS
            "verifications", "subquery_three"."consensus" AS "consensus" FROM
            "bucketed_time_series" CROSS JOIN (SELECT DISTINCT tag_id FROM
            base_table) distinct_tags LEFT OUTER JOIN "base_table" ON
            ("bucketed_time_series"."time_bucket" @>
            "base_table"."start_time_absolute") AND ("base_table"."tag_id" =
            "distinct_tags"."tag_id") LEFT OUTER JOIN "verification_base" ON
            ("base_table"."audio_event_id" =
            "verification_base"."audio_event_id") AND ("base_table"."tag_id" =
            "verification_base"."tag_id") LEFT OUTER JOIN (SELECT
            "subquery_two"."audio_event_id", "subquery_two"."tag_id",
            AVG("subquery_two"."ratio") AS "consensus" FROM (SELECT
            "subquery_one"."audio_event_id", "subquery_one"."tag_id",
            "subquery_one"."confirmed", "subquery_one"."ratio", ROW_NUMBER()
            OVER (PARTITION BY tag_id, audio_event_id ORDER BY ratio DESC) AS
            "row_number" FROM (SELECT "verification_base"."audio_event_id",
            "verification_base"."tag_id", "verification_base"."confirmed",
            (CAST(COUNT("verification_base"."verification_id") AS float) /
            SUM(COUNT("verification_base"."verification_id")) OVER (PARTITION BY
            "verification_base"."audio_event_id", "verification_base"."tag_id"))
            AS "ratio" FROM "verification_base" WHERE
            "verification_base"."confirmed" IS NOT NULL GROUP BY
            "verification_base"."audio_event_id", "verification_base"."tag_id",
            "verification_base"."confirmed") "subquery_one") "subquery_two"
            WHERE "subquery_two"."row_number" = 1 GROUP BY
            "subquery_two"."audio_event_id", "subquery_two"."tag_id",
            "subquery_two"."row_number") "subquery_three" ON
            ("subquery_three"."audio_event_id" =
            "verification_base"."audio_event_id") AND ("subquery_three"."tag_id"
            = "verification_base"."tag_id") GROUP BY
            "bucketed_time_series"."bucket_number",
            "bucketed_time_series"."time_bucket", "distinct_tags"."tag_id",
            "subquery_three"."consensus") SELECT ARRAY_AGG(DISTINCT site_ids) AS
            "site_ids", ARRAY_AGG(DISTINCT region_ids) AS "region_ids",
            ARRAY_AGG(DISTINCT tag_id) AS "tag_ids", ARRAY_AGG(DISTINCT
            audio_recording_ids) AS "audio_recording_ids", ARRAY_AGG(DISTINCT
            provenance_id) AS "provenance_ids", COUNT(DISTINCT
            "base_table"."audio_event_id") AS "audio_events_count", (SELECT
            json_agg(row_to_json(t)) FROM "cumulative_unique_tag_series" AS "t")
            "accumulation_series", (SELECT json_agg(e) FROM "event_summaries" AS
            "e") "event_summaries", (SELECT json_agg(c) FROM
            "composition_series" AS "c") "composition_series" FROM "base_table"
          SQL
        )
  end

  def scratchpad
    ##
    out = ActiveRecord::Base.connection.execute(
      <<~SQL
        SELECT audio_events.id as audio_event_id,
               sites.id as site_id,
               audio_events_tags.id as audio_event_tag_id,
               audio_events.start_time_seconds,
               audio_events.end_time_seconds
        FROM audio_events
        JOIN audio_events_tags ON audio_events_tags.audio_event_id = audio_events.id
        JOIN audio_recordings ON audio_recordings.id = audio_events.audio_recording_id
        JOIN sites ON sites.id = audio_recordings.site_id

      SQL
    )
    ##
  end

  def scratch
    audio_events = AudioEvent.arel_table
    verifications = Verification.arel_table

    verif_left_join = verifications.project(:id).as('verification_id').from(verifications)
    table_alias = Arel::Nodes::TableAlias.new(verif_left_join, 'v')
    verifications_alias_table = Arel::Nodes::As.new(verifications)
    select = audio_events.project(
      audio_events[:id]
    ).from(audio_events)
      .join(verif_left_join)
      .on(audio_events[:id].eq(verifications_alias_table[:audio_event_id]))

    verif_left_join_aliased = Arel::Nodes::As.new(verif_left_join, 'v')
  end
end

# important subquery patterns to know
def patterns_for_subqueries_in_arel
  audio_events = AudioEvent.arel_table
  verifications = Verification.arel_table

  p 'start with this'
  main_select = audio_events.project(audio_events[:id]).from(audio_events)
  p main_select.to_sql

  p 'i want verification id from a joined subquery, so I make the subquery first:'
  verif_subquery = verifications.project(:id).as('verification_id').from(verifications)
  p verif_subquery.to_sql

  p 'now I make a table alias for the subquery'
  verif_subquery_table_alias = Arel::Nodes::TableAlias.new(verif_subquery, 'v')
  p verif_subquery_table_alias.to_sql

  p 'There are two important things that can happen when using the table alias'
  p 'If I use the table alias directly in the main select, it will embed the subquery in the main select'
  p 'This query is not valid but it shows the pattern of how the sql it built differently depending on how you use things'
  main_select_v1 = audio_events.project(audio_events[:id], verif_subquery).from(audio_events)
  p main_select_v1.to_sql

  p 'If I use the table alias with a column selection, it will actually just input the correct alias . column notation'
  main_select_v2 = audio_events.project(audio_events[:id], verif_subquery_table_alias[:id]).from(audio_events)
  p main_select_v2.to_sql

  p 'Now I can add the from clause to the main select'
  p 'And we have a correctly aliased from clause with the correct aliased column selection'
  p 'And this query runs correctly'
  main_select_v2 = audio_events
    .project(audio_events[:id].as('audio_event_id'), verif_subquery_table_alias[:id].as('verification_id'))
    .from([audio_events, verif_subquery_table_alias])
  p main_select_v2.to_sql

  p 'Let\'s try to use the subqyery as a join instead'
  main_select_v3 = audio_events
    .project(audio_events[:id].as('audio_event_id'), verif_subquery_table_alias[:id].as('verification_id'))
    .from(audio_events)
    .join(verif_subquery_table_alias, Arel::Nodes::OuterJoin)
    .on(audio_events[:id].eq(verif_subquery_table_alias[:audio_event_id]))
  p main_select_v3.to_sql

  p 'Note I made an important mistake above and the query failed to execute'
  p 'ERROR:  column v.audio_event_id does not exist (PG::UndefinedColumn)'
  p 'If you create a derived table with a subquery, it only includes the queries explicitly selected in the subquery'
  p "I didn't select audio_event_id in the subquery originally, which meant I couldn't join on it"
  p 'here is the fix'
  verif_subquery = verifications.project(:id, :audio_event_id).as('verification_id').from(verifications)

  verif_subquery_table_alias = Arel::Nodes::TableAlias.new(verif_subquery, 'v')

  main_select_v4 = audio_events
    .project(audio_events[:id].as('audio_event_id'), verif_subquery_table_alias[:id].as('verification_id'))
    .from(audio_events)
    .join(verif_subquery_table_alias, Arel::Nodes::OuterJoin)
    .on(audio_events[:id].eq(verif_subquery_table_alias[:audio_event_id]))

  p main_select_v4.to_sql
  ActiveRecord::Base.connection.execute(main_select_v4.to_sql).to_a

  p 'If I wanted to have a derived table from a subquery that is from a subquery, I can do that too'
  p 'derived_table <-- (left_join --- (subquery_two <-- (from --- subquery_one))'
  subquery_one = verifications.project(verifications[:tag_id], verifications[:audio_event_id], verifications[:audio_event_id].count).from(verifications).group(
    verifications[:tag_id], verifications[:audio_event_id]
  )
  ActiveRecord::Base.connection.execute(subquery_one.to_sql).to_a

  subquery_one_table_alias = Arel::Nodes::TableAlias.new(subquery_one, 'subquery_one')

  subquery_two = Arel::SelectManager.new
    .project(subquery_one_table_alias[:tag_id], subquery_one_table_alias[:audio_event_id], subquery_one_table_alias[:count])
    .from(subquery_one_table_alias)
  subquery_two.to_sql

  ActiveRecord::Base.connection.execute(subquery_two.to_sql).to_a

  "
  The pattern so far is this:
  SUBQUERY = PROJECT from base table
  ALIAS the SUBQUERY using table alias --- you have an actual Select manager object AND a table alias now
  QUERY TWO -> new select manager -> use ALIAS for projections -> use ALIAS as from
  "

  p 'Now the main query with a left join to subquery_two'
  subquery_two_table_alias = Arel::Nodes::TableAlias.new(subquery_two, 'subquery_two')
  main_query = audio_events
    .project(
      audio_events[:id].as('audio_event_id'),
      subquery_two_table_alias[:tag_id],
      subquery_two_table_alias[:count]
    )
    .from(audio_events)
    .join(subquery_two_table_alias, Arel::Nodes::OuterJoin)
    .on(audio_events[:id].eq(subquery_two_table_alias[:audio_event_id]))
  p main_query.to_sql
  ActiveRecord::Base.connection.execute(main_query.to_sql).to_a
end
