# frozen_string_literal: true

describe Filter::Query do
  create_entire_hierarchy

  include SqlHelpers::Example

  def compare_filter_sql(filter, sql_result)
    filter_query = create_filter(filter)
    comparison_sql(filter_query.query_full.to_sql, sql_result)
    filter_query
  end

  def create_filter(params)
    Filter::Query.new(
      params,
      AudioRecording.all,
      AudioRecording,
      AudioRecording.filter_settings
    )
  end

  context 'when using expressions' do
    context 'with bad input will error' do
      it 'fails with an expression function that does not exist' do
        expect {
          create_filter(
            {
              filter: {
                recorded_date: {
                  eq: { expressions: ['month'], value: '06:00' }
                }
              }
            }
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Expression function `month` does not exist')
      end

      it 'fails without a value' do
        expect {
          create_filter(
            {
              filter: {
                recorded_date: {
                  eq: { expressions: ['local_offset', 'time_of_day'] }
                }
              }
            }
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Expression must contain a value')
      end

      it 'fails with only one value' do
        expect {
          create_filter(
            {
              filter: {
                recorded_date: {
                  eq: { expressions: [], value: '06:00' }
                }
              }
            }
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Expressions must contain at least one function')
      end

      it 'fails with no expressions key' do
        expect {
          create_filter(
            {
              filter: {
                recorded_date: {
                  eq: { value: '06:00' }
                }
              }
            }
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Expressions object must contain an expressions array')
      end
    end

    context 'with dates' do
      it 'can convert a UTC date to local time' do
        params = {
          projection: {
            include: [
              :recorded_date
            ]
          },
          filter: {
            recorded_date: {
              eq: { expressions: ['local_tz'], value: '2022-02-02T22:22' }
            }
          }
        }

        complex_result = <<~SQL.squish
          SELECT "audio_recordings"."recorded_date"
          FROM "audio_recordings"
          LEFT OUTER JOIN "sites"
          ON ("sites"."deleted_at" IS NULL)
          AND ("sites"."id" = "audio_recordings"."site_id")
          WHERE ("audio_recordings"."deleted_at" IS NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND ((("audio_recordings"."recorded_date" AT TIME ZONE 'UTC') AT TIME ZONE "sites"."tzinfo_tz") = (('2022-02-02T22:22' AT TIME ZONE 'UTC') AT TIME ZONE "sites"."tzinfo_tz"))
          ORDER BY "audio_recordings"."recorded_date" DESC
          LIMIT 25 OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'can convert a UTC date to a local time, with a fixed offset' do
        params = {
          projection: {
            include: [
              :recorded_date
            ]
          },
          filter: {
            recorded_date: {
              eq: { expressions: ['local_offset'], value: '2022-02-02T22:22' }
            }
          }
        }

        complex_result = <<~SQL.squish
          WITH "offset_table" AS (
            SELECT "pg_timezone_names"."name",
              CASE "pg_timezone_names"."is_dst" WHEN TRUE THEN ("pg_timezone_names"."utc_offset" - '3600 SECONDS'::interval)
              ELSE "pg_timezone_names"."utc_offset" END
              AS "base_offset"
            FROM "pg_timezone_names")
          SELECT "audio_recordings"."recorded_date"
          FROM "audio_recordings"
          LEFT OUTER JOIN "sites"
          ON ("sites"."deleted_at" IS NULL) AND ("sites"."id" = "audio_recordings"."site_id")
          INNER JOIN "offset_table"
          ON "sites"."tzinfo_tz" = "offset_table"."name"
          WHERE ("audio_recordings"."deleted_at" IS NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND ((("audio_recordings"."recorded_date" AT TIME ZONE 'UTC') AT TIME ZONE "offset_table"."base_offset") = (('2022-02-02T22:22' AT TIME ZONE 'UTC') AT TIME ZONE "offset_table"."base_offset"))
          ORDER BY "audio_recordings"."recorded_date" DESC
          LIMIT 25 OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'can convert a UTC date to a local time of day' do
        params = {
          projection: {
            include: [
              :recorded_date
            ]
          },
          filter: {
            recorded_date: {
              eq: { expressions: ['local_tz', 'time_of_day'], value: '22:22' }
            }
          }
        }

        complex_result = <<~SQL.squish
          SELECT "audio_recordings"."recorded_date"
          FROM "audio_recordings"
          LEFT OUTER JOIN "sites"
          ON ("sites"."deleted_at" IS NULL)
          AND ("sites"."id" = "audio_recordings"."site_id")
          WHERE ("audio_recordings"."deleted_at" IS NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND (CAST((("audio_recordings"."recorded_date" AT TIME ZONE 'UTC') AT TIME ZONE "sites"."tzinfo_tz") AS time) = CAST('22:22' AS time))
          ORDER BY "audio_recordings"."recorded_date" DESC
          LIMIT 25 OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'can convert a UTC date to a local time of day, with a fixed offset' do
        params = {
          projection: {
            include: [
              :recorded_date
            ]
          },
          filter: {
            recorded_date: {
              eq: { expressions: ['local_offset', 'time_of_day'], value: '22:22' }
            }
          }
        }

        complex_result = <<~SQL.squish
          WITH "offset_table" AS (
            SELECT "pg_timezone_names"."name",
              CASE "pg_timezone_names"."is_dst" WHEN TRUE THEN ("pg_timezone_names"."utc_offset" - '3600 SECONDS'::interval)
              ELSE "pg_timezone_names"."utc_offset" END
              AS "base_offset"
            FROM "pg_timezone_names")
          SELECT "audio_recordings"."recorded_date"
          FROM "audio_recordings"
          LEFT OUTER JOIN "sites"
          ON ("sites"."deleted_at" IS NULL)
          AND ("sites"."id" = "audio_recordings"."site_id")
          INNER JOIN "offset_table"
          ON "sites"."tzinfo_tz" = "offset_table"."name"
          WHERE ("audio_recordings"."deleted_at" IS NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND (CAST((("audio_recordings"."recorded_date" AT TIME ZONE 'UTC') AT TIME ZONE "offset_table"."base_offset") AS time) = CAST('22:22' AS time))
          ORDER BY "audio_recordings"."recorded_date" DESC
          LIMIT 25 OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'can convert a UTC date to a time of day' do
        params = {
          projection: {
            include: [
              :recorded_date
            ]
          },
          filter: {
            recorded_date: {
              eq: { expressions: ['time_of_day'], value: '22:22' }
            }
          }
        }

        complex_result = <<~SQL.squish
          SELECT "audio_recordings"."recorded_date"
          FROM "audio_recordings"
          WHERE ("audio_recordings"."deleted_at" IS NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND (
          CAST("audio_recordings"."recorded_date" AS time) =
          CAST('22:22' AS time))
          ORDER BY "audio_recordings"."recorded_date" DESC
          LIMIT 25 OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'can convert a UTC date to a local time of day, with a fixed offset, with a real world complex example' do
        params = {
          projection: {
            include: [
              :recorded_date
            ]
          },
          filter: {
            or: {
              recorded_end_date: {
                gteq: { expressions: ['local_offset', 'time_of_day'], value: '03:00' }
              },
              recorded_date: {
                lteq: { expressions: ['local_offset', 'time_of_day'], value: '05:00' }
              }
            }
          }
        }

        complex_result = <<~SQL.squish
          WITH "offset_table" AS (
            SELECT "pg_timezone_names"."name",
              CASE "pg_timezone_names"."is_dst" WHEN TRUE THEN ("pg_timezone_names"."utc_offset" - '3600 SECONDS'::interval)
              ELSE "pg_timezone_names"."utc_offset" END
              AS "base_offset"
            FROM "pg_timezone_names")
          SELECT "audio_recordings"."recorded_date"
          FROM "audio_recordings"
          LEFT OUTER JOIN "sites"
          ON ("sites"."deleted_at" IS NULL) AND ("sites"."id" = "audio_recordings"."site_id")
          INNER JOIN "offset_table"
          ON "sites"."tzinfo_tz" = "offset_table"."name"
          WHERE ("audio_recordings"."deleted_at" IS NULL)
          AND ("audio_recordings"."status" = 'ready')
          AND (((CAST(((("audio_recordings"."recorded_date" + CAST("audio_recordings"."duration_seconds" || ' seconds' as interval)) AT TIME ZONE 'UTC') AT TIME ZONE "offset_table"."base_offset") AS time) >= CAST('03:00' AS time))
          OR (CAST((("audio_recordings"."recorded_date" AT TIME ZONE 'UTC') AT TIME ZONE "offset_table"."base_offset") AS time) <= CAST('05:00' AS time))))
          ORDER BY "audio_recordings"."recorded_date" DESC
          LIMIT 25 OFFSET 0
        SQL
        compare_filter_sql(params, complex_result)
      end

      it 'fails if a model cannot provide a timezone' do
        expect {
          Filter::Query.new(
            {
              filter: {
                created_at: {
                  eq: { expressions: ['local_offset'], value: '2022' }
                }
              }
            },
            Tag.all,
            Tag,
            Tag.filter_settings
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Cannot use `local_offset` or `local_tz` with the `Tag` model because it does have timezone information')
      end

      it 'ensures local_offset comes before time_of_day' do
        expect {
          create_filter(
            {
              filter: {
                recorded_date: {
                  eq: { expressions: ['time_of_day', 'local_offset'], value: '06:00' }
                }
              }
            }
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Expression function `local_offset` or `local_tz` is not compatible with type `time`')
      end

      it 'ensures local_tz comes before time_of_day' do
        expect {
          create_filter(
            {
              filter: {
                recorded_date: {
                  eq: { expressions: ['time_of_day', 'local_tz'], value: '06:00' }
                }
              }
            }
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Expression function `local_offset` or `local_tz` is not compatible with type `time`')
      end

      it 'fails if a non-time is given to a time_of_day filter' do
        expect {
          create_filter(
            {
              projection: {
                include: [
                  :recorded_date
                ]
              },
              filter: {
                recorded_date: {
                  eq: { expressions: ['local_tz', 'time_of_day'], value: '2022-02-02T22:22' }
                }
              }
            }
          ).query_full
        }.to raise_error(CustomErrors::FilterArgumentError,
          'Filter parameters were not valid: Expression time_of_day must be supplied with a time, got `2022-02-02T22:22`')
      end

      context 'when using an unsupported type' do
        [
          [:integer, :id],
          [:string, :status]
        ].each do |type, name|
          it "does not support #{type} for the local function" do
            expect {
              create_filter(
                {
                  filter: {
                    name => {
                      eq: { expressions: ['local_offset'], value: '123' }
                    }
                  }
                }
              ).query_full
            }.to raise_error(CustomErrors::FilterArgumentError,
              "Filter parameters were not valid: Expression function `local_offset` or `local_tz` is not compatible with type `#{type}`")
          end
        end
      end
    end
  end
end
