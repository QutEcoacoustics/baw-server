# frozen_string_literal: true

# AudioEventReport uses the report module to generate a report on audio events
module AudioEventReport
  module_function

  module QueryExtensions
    refine Arel::SelectManager do
      def add_joins
        join(Arel::Table.new(:taggings))
          .on(Arel::Table.new(:audio_events)[:id].eq(Arel::Table.new(:taggings)[:audio_event_id]))
          .join(Arel::Table.new(:tags))
          .on(Arel::Table.new(:taggings)[:tag_id].eq(Arel::Table.new(:tags)[:id]))
      end
    end
  end
  using QueryExtensions

  def attributes
    [
      sites[:id].as('site_ids'),
      tags[:id].as('tag_ids'),
      audio_events[:audio_recording_id].as('audio_recording_ids'),
      audio_events[:provenance_id].as('provenance_ids'),
      audio_events[:id].as('audio_event_id'),
      audio_recordings[:recorded_date],
      Arel::Nodes::SqlLiteral.new(start_time_absolute_expression),
      Arel::Nodes::SqlLiteral.new(end_time_absolute_expression)
    ]
  end

  # @param filter_params [ActionController::Parameters] the filter parameters
  # @param base_scope [ActiveRecord::Relation] the base scope for the query
  def generate_report(filter_params, base_scope)
    # configuration from filter_params
    filter_params_hash = Report::Configuration.filter_params_to_hash(filter_params)
    report_range = Report::Configuration.parse_report_range(filter_params_hash)
    bucket_size = Report::Buckets.parse_size(filter_params_hash)

    # build the base filtered query
    filtered_base = filter_as_relation(filter_params, base_scope)
    # apply the attributes
    debugger
    base = filtered_base.arel.project(attributes).add_joins
    # apply the joins

    # join verifications with right outer join to get all verifications or
    # something similar. or aggregate first and get values needed etc.
    @cte_table = Arel::Table.new('filtered_basis')
    @cte = Arel::Nodes::As.new(@cte_table, base)
    @query = Arel::SelectManager.new
  end

  #  A provenances CTE if needed
  def provenance_cte
    prov_query = @cte_table
      .join(provenance, Arel::Nodes::OuterJoin)
      .on(@cte_table[:provenance_id].eq(provenance[:id]))
      .from(@cte_table)
      .project(provenance[:id].as('provenance_ids'))

    prov_table = Arel::Table.new('provenance')
    prov_cte = Arel::Nodes::As.new(prov_table, prov_query)
    [prov_table, prov_cte]
  end

  def start_time_absolute_expression
    'audio_recordings.recorded_date + CAST(audio_events.start_time_seconds || \' seconds\' as interval)' \
      'as start_time_absolute'
  end

  def end_time_absolute_expression
    'audio_recordings.recorded_date + CAST(audio_events.end_time_seconds || \' seconds\' as interval)' \
      'as end_time_absolute'
  end

  def datetime_range
    Arel::Nodes::SqlLiteral.new("
        array_to_json(ARRAY[
          to_char(true_start_time, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),
          to_char(true_end_time, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')
        ])
      ").as('range')
  end

  def generate
    debugger
    @query
      .with(@cte)
      .project(aggregate_distinct(:site_ids))
      .project(aggregate_distinct(:audio_recording_ids))
      .project(aggregate_distinct(:tag_ids))
      .project(aggregate_distinct(:provenance_ids))
      .from([@cte_table])

    @query.to_sql
  end

  def parse_date_ranges(result_set)
    # something like this
    result_set.each_with_index { |_item, index| result_set[index]['range'] = JSON.parse(result_set[index].values[0]) }
  end

  # @param filter_params [ActionController::Parameters] the filter parameters
  # @param base_scope [ActiveRecord::Relation] the base scope for the query
  def filter_as_relation(filter_params, base_scope)
    filter_query = Filter::Query.new(
      filter_params,
      base_scope,
      AudioEvent,
      AudioEvent.filter_settings
    )
    filter_query.query_without_paging_sorting
  end

  # Get an aggregated array of distinct values for a field
  # @param field [Symbol] the field to aggregate
  def aggregate_distinct(field)
    Arel::Nodes::NamedFunction.new(
      'ARRAY_AGG',
      [Arel::Nodes::SqlLiteral.new("DISTINCT #{@cte_table[field].name}")]
    ).as(field.to_s)
  end

  def audio_events = AudioEvent.arel_table
  def audio_recordings = AudioRecording.arel_table
  def sites = Site.arel_table
  def regions = Region.arel_table
  def tags = Tag.arel_table
  def taggings = Tagging.arel_table
  def provenance = Provenance.arel_table

  # Determine date range for the report
  # In a real implementation, this will come from filter parameters
  # @return [Hash] Start and end dates for the report
  def date_range
    { start_date: '2025-01-01T00:00:00Z', end_date: '2025-01-08T00:00:00Z' }
  end

  def datetime_range_to_array(start_field, end_field)
    Arel::Nodes::SqlLiteral.new("
        array_to_json(ARRAY[
          to_char(#{start_date}, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'),
          to_char(#{end_date}, 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"')
        ])
      ").as('range')
  end

  # Method to calculate the accumulation series for the report
  def accumulation_series
    # Get date range
    start_date, end_date = date_range

    # Calculate the number of bins needed
    bin_count_sql = "
        CEIL(
          EXTRACT(EPOCH FROM ('#{end_date}'::timestamp - '#{start_date}'::timestamp)) /
          EXTRACT(EPOCH FROM interval '#{bin_interval}')
        )::integer
      "

    # Create the bucketing query using width_bucket correctly
    # PostgreSQL's width_bucket can work with timestamp operands when properly cast
    bucket_table = Arel::Table.new('bucketed_data')

    bucket_query = Arel::SelectManager.new
    bucket_query.with([@cte])
    bucket_query.from([@cte_table])
    bucket_query.project(
      # The correct way to use width_bucket with timestamps
      # the value is the event start time, we are binning each event based on
      # start time within the range of start_date and end_date
      # here we got one row per datum with the bucket number that the datum
      # falls in, and the value of tag id
      Arel::Nodes::SqlLiteral.new("
          width_bucket(
            extract(epoch from true_start_time),
            extract(epoch from '#{start_date}'::timestamp),
            extract(epoch from '#{end_date}'::timestamp),
            #{bin_count_sql}
          ) AS bucket
        "),
      @cte_table[:tag_ids]
    )

    # Create CTE for the bucketed data
    bucket_cte = Arel::Nodes::As.new(bucket_table, bucket_query)

    # Now create the accumulation query using the bucketed data
    accumulation_query = Arel::SelectManager.new
    accumulation_query.with([@cte, bucket_cte])
    accumulation_query.from([bucket_table])

    # Calculate the bin start and end dates
    bin_interval_seconds = Arel::Nodes::SqlLiteral.new("
        extract(epoch from '#{end_date}'::timestamp) - extract(epoch from '#{start_date}'::timestamp)
      ")

    bin_size_seconds = Arel::Nodes::SqlLiteral.new("
        (#{bin_interval_seconds}) / #{bin_count_sql}
      ")

    # Project the range, count, and score
    accumulation_query.project(
      Arel::Nodes::SqlLiteral.new("
          array_to_json(ARRAY[
            to_char(
              '#{start_date}'::timestamp +
              ((bucket - 1) * (interval '1 second' * #{bin_size_seconds})),
              'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'
            ),
            to_char(
              '#{start_date}'::timestamp +
              (bucket * (interval '1 second' * #{bin_size_seconds})),
              'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'
            )
          ])
        ").as('range'),
      Arel::Nodes::SqlLiteral.new('COUNT(DISTINCT tag_ids)').as('count'),
      Arel::Nodes::SqlLiteral.new('0').as('score')
    )

    # Group and order by the bucket
    accumulation_query.group(bucket_table[:bucket])
    accumulation_query.order(bucket_table[:bucket])

    # Execute the query and parse the results
    result_set = ActiveRecord::Base.connection.execute(accumulation_query.to_sql)

    # Parse the date ranges in the result set
    parse_date_ranges(result_set)
  end
end

def pow
  <<~SQL.squish
                WITH filtered_basis AS (#{@cte.right.to_sql}),
                -- temporary; remove
                -- define the time boundaries for the reporting period and bucket size
                time_boundaries AS (
                    SELECT
                        '2025-01-01T00:00:00Z'::timestamp AS report_start_time,
                        '2025-01-08T00:00:00Z'::timestamp AS report_end_time,
                        interval '1 day' AS bucket_interval
                ),
                -- calculate the exact number of buckets needed by:
                -- 1. converting both timestamps to epoch seconds using EXTRACT(EPOCH FROM timestamp)
                -- 2. subtracting start from end to get the total duration in seconds
                -- 3. dividing by the bucket interval (also converted to seconds) to get bucket count
                calculated_settings AS (
                    SELECT
                        (SELECT (EXTRACT(EPOCH FROM report_end_time) - EXTRACT(EPOCH FROM report_start_time)) /
                                EXTRACT(EPOCH FROM bucket_interval)
                         FROM time_boundaries) AS bucket_count, -- The result is the exact number of buckets needed (may be a decimal)
                        (SELECT report_start_time FROM time_boundaries) AS min_value,
                        (SELECT report_end_time FROM time_boundaries) AS max_value
                ),
                -- Generate all time buckets with their respective boundaries
                all_buckets AS (
                    SELECT
                        -- Generate a sequence of integers for bucket numbering:
                        -- Starting at: 1 (first bucket)
                        -- Ending at: The ceiling of bucket_count (rounded up to ensure we cover the entire time range)
                        -- Ceiling function takes a decimal value and rounds it up to the nearest integer
                        -- ::integer explicitly casts the decimal to an integer type required by generate_series
                        generate_series(1, (SELECT CEILING(bucket_count) FROM calculated_settings)::integer) AS bucket_number, -- Each number in this sequence becomes a bucket identifier
                        -- Calculate the start time for each bucket by:
                        -- 1. Starting with the overall minimum value (report_start_time)
                        -- 2. Adding an offset: (bucket_number - 1) * bucket_interval
                        -- The subtraction of 1 ensures bucket 1 starts exactly at the minimum value
                        (SELECT min_value FROM calculated_settings) +
                        -- Start value 1 matches the bucket numbering, end value matches the bucket numbering
                        ((generate_series(1, (SELECT CEILING(bucket_count) FROM calculated_settings)::integer) - 1) *
                        (SELECT bucket_interval FROM time_boundaries)) AS bucket_start_time,
                        -- Calculate the end time for each bucket by:
                        -- 1. Starting with the overall minimum value (report_start_time)
                        -- 2. Adding an offset: bucket_number * bucket_interval
                        -- This formula makes each bucket end exactly where the next one begins
                        (SELECT min_value FROM calculated_settings) +
                        (generate_series(1, (SELECT CEILING(bucket_count) FROM calculated_settings)::integer) *
                        (SELECT bucket_interval FROM time_boundaries)) AS bucket_end_time
                ),
                -- Assign each data point to the appropriate bucket using WIDTH_BUCKET function
                data_with_buckets AS (
                    SELECT
                        -- WIDTH_BUCKET assigns a bucket number (1 to N) based on where a value falls in a range
                        -- Arguments: test_value, min_range, max_range, number_of_buckets
                        -- Since WIDTH_BUCKET doesn't work with timestamps directly, we:
                        -- 1. Convert all timestamps to epoch seconds (numeric) using EXTRACT(EPOCH FROM timestamp)
                        -- 2. Apply WIDTH_BUCKET to these numeric values
                        WIDTH_BUCKET(
                            EXTRACT(EPOCH FROM start_time_absolute), -- Convert data timestamp to seconds since epoch
                            EXTRACT(EPOCH FROM (SELECT min_value FROM calculated_settings)), -- Convert min timestamp to seconds
                            EXTRACT(EPOCH FROM (SELECT max_value FROM calculated_settings)), -- Convert max timestamp to seconds
                            (SELECT CEILING(bucket_count)::integer FROM calculated_settings) -- Number of buckets (ceiling ensures we cover full range)
                        ) AS bucket, -- The resulting bucket number for each data point
                        tag_ids -- Keep the tag_ids from the original data for later analysis
                    FROM filtered_basis -- Source table containing the raw data points
                ),
                -- Identify the first occurrence of each tag_id in any bucket
                first_appearances AS (
                    SELECT
                        bucket, -- Keep the bucket number for grouping
                        -- For each tag_id, determine if this is its first appearance across all buckets:
                        -- 1. ROW_NUMBER() OVER (PARTITION BY tag_ids ORDER BY bucket) assigns a sequence number to each tag_id's appearances
                        -- 2. CASE WHEN checks if this sequence number is 1 (first appearance)
                        -- 3. If it's the first appearance, assign 1, otherwise assign 0
                        CASE WHEN ROW_NUMBER() OVER (PARTITION BY tag_ids ORDER BY bucket) = 1 THEN 1 ELSE 0 END AS is_first_time
                    FROM data_with_buckets -- Use the data that's already assigned to buckets
                    WHERE bucket IS NOT NULL -- Ignore any data points that couldn't be assigned to a bucket
                    )
        -- Final SELECT statement to produce the report component
        SELECT
        all_buckets.bucket_number, -- The sequential bucket identifier
        all_buckets.bucket_start_time, -- The start timestamp of this bucket
        all_buckets.bucket_end_time, -- The end timestamp of this bucket
        -- Calculate the cumulative sum of new unique tags up to the current bucket:
        -- 1. The subquery (SELECT SUM(fa_inner.is_first_time)...) calculates the sum of first appearances in the current bucket
        -- 2. SUM(...) OVER (ORDER BY all_buckets.bucket_number) creates a running sum ordered by bucket
        -- 3. COALESCE(..., 0) replaces any NULL values with 0
        -- 4. ::INTEGER explicitly casts the result to integer format to avoid scientific notation
        COALESCE(
            SUM(bucket_sums.tag_count) OVER (ORDER BY all_buckets.bucket_number),
            0
        )::INTEGER AS cumulative_unique_tag_ids_count
    FROM all_buckets -- Start with the complete set of time buckets
    -- LEFT JOIN to include all buckets even if no data points fall into them
    -- Get the sum of first appearances for each bucket
    -- These sums are used above in the window function to calculate the cumulative count
    LEFT JOIN (
        SELECT
            bucket,
            SUM(is_first_time) AS tag_count
        FROM first_appearances
        GROUP BY bucket
    ) bucket_sums ON all_buckets.bucket_number = bucket_sums.bucket
    ORDER BY all_buckets.bucket_number; -- order the final result by bucket number for chronological presentation
  SQL
end

# easier to read because the order of the expressions match the order of
# execution, compared to above.
def alternative_end
  <<~SQL.squish
          bucket_counts AS (
            SELECT
                bucket,
                SUM(is_first_time) AS new_unique_tags
            FROM first_appearances
            GROUP BY bucket
        )
    SELECT
        all_buckets.bucket_number,
        all_buckets.bucket_start_time,
        all_buckets.bucket_end_time,
        COALESCE(SUM(bc.new_unique_tags) OVER (ORDER BY all_buckets.bucket_number), 0) AS cumulative_unique_tagids_count
    FROM all_buckets
    LEFT JOIN bucket_counts bc ON all_buckets.bucket_number = bc.bucket
    ORDER BY all_buckets.bucket_number;
  SQL
end
