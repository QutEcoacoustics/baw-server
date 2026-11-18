# frozen_string_literal: true

describe Filter::Query do
  context 'with association scopes' do
    include SqlHelpers::Example

    def scope_sql(filter, model: AudioEvent, settings: model.filter_settings)
      Filter::Query.new(
        { projection: { only: [:id] }, filter: },
        model.unscoped,
        model,
        settings
      ).query_full.to_sql.squish
    end

    context 'with invalid input' do
      it 'rejects invalid scopes' do
        expect {
          scope_sql({ banana: { any: { creator_id: { eq: 14 } } } })
        }.to raise_error(CustomErrors::FilterArgumentError, /Unrecognized combiner, scope, or field name `banana`/)
      end

      # sites -> audio_recordings -> audio_events -> verifications.
      # Site's filter settings do not declare verifications at any depth.
      it 'rejects a scope on a distant association not declared in the filter settings' do
        expect {
          scope_sql({ verifications: { any: { creator_id: { eq: 14 } } } }, model: Site)
        }.to raise_error(
          CustomErrors::FilterArgumentError,
          /Unrecognized combiner, scope, or field name `verifications`./
        )
      end

      it 'rejects a scope applied on a parent association' do
        expect {
          scope_sql({ audio_recordings: { any: {} } })
        }.to raise_error(
          CustomErrors::FilterArgumentError,
          /The `audio_recordings` scope is invalid for this resource, it is not a child association\./
        )
      end

      it 'rejects a scope applied on a one-to-one association' do
        expect {
          scope_sql({ harvest_items: { any: {} } }, model: AudioRecording)
        }.to raise_error(
          CustomErrors::FilterArgumentError,
          /The `harvest_items` scope is invalid for this resource, it is not a child association\./
        )
      end

      # audio_event_imports -> audio_event_import_files -> audio_events.
      # The filter settings declare audio_events, but nested under audio_event_import_files.
      it 'rejects a scope on a declared association nested under another association' do
        expect {
          scope_sql({ audio_events: { any: {} } }, model: AudioEventImport)
        }.to raise_error(
          CustomErrors::FilterArgumentError,
          /The `audio_events` scope is invalid because it is not an immediate association/
        )
      end

      it 'rejects an unavailable association' do
        settings = AudioEvent.filter_settings.deep_dup
        settings[:valid_associations].find { |association| association[:join] == Verification }[:available] = false

        expect {
          scope_sql({ verifications: { any: {} } }, settings:)
        }.to raise_error(CustomErrors::FilterArgumentError,
          /Unrecognized combiner, scope, or field name `verifications`/)
      end

      [nil, false, 1, 'any', [], [{ any: {} }]].each do |value|
        it "rejects a non-object scope value `#{value.inspect}`" do
          expect {
            scope_sql({ verifications: value })
          }.to raise_error(CustomErrors::FilterArgumentError, /The `verifications` scope value must be an object/)
        end
      end

      it 'rejects a scope with no operator' do
        expect {
          scope_sql({ verifications: {} })
        }.to raise_error(CustomErrors::FilterArgumentError,
          /The `verifications` scope must have an operator, one of `any`, `none`, or `all`/)
      end

      it 'rejects an unknown scope operator' do
        expect {
          scope_sql({ verifications: { sometimes: {} } })
        }.to raise_error(CustomErrors::FilterArgumentError,
          /The `verifications` scope operator `sometimes` is invalid, it must be one of `any`, `none`, or `all`/)
      end

      it 'rejects multiple operators in one scope' do
        expect {
          scope_sql({ verifications: { any: {}, none: {} } })
        }.to raise_error(CustomErrors::FilterArgumentError,
          /Filter parameters were not valid: The `verifications` scope must have an operator, one of `any`, `none`, or `all`/)
      end

      [:any, :none, :all].each do |operator|
        [nil, false, 1, 'skip', [], [{ confirmed: { eq: 'skip' } }]].each do |value|
          it "rejects a non-object inner filter #{value.inspect} for #{operator}" do
            expect {
              scope_sql({ verifications: { operator => value } })
            }.to raise_error(
              CustomErrors::FilterArgumentError,
              /The `verifications` scope inner filter for `#{operator}` must be an object/
            )
          end
        end

        it "rejects an unknown field inside `#{operator}`" do
          expect {
            scope_sql({ verifications: { operator => { banana: { eq: 14 } } } })
          }.to raise_error(CustomErrors::FilterArgumentError, /Unrecognized combiner, scope, or field name `banana`/)
        end

        it "rejects an unknown comparison inside `#{operator}`" do
          expect {
            scope_sql({ verifications: { operator => { creator_id: { banana: 14 } } } })
          }.to raise_error(CustomErrors::FilterArgumentError, /Unrecognized combiner, scope, or field name `banana`/)
        end

        # audio_recordings -> audio_events -> taggings -> verifications nests three scopes
        [nil, :and, :or, :not].each do |combiner|
          it "rejects a scope nested too deeply inside `#{operator}` under `#{combiner || 'the inner filter'}`" do
            too_deep = { verifications: { operator => {} } }
            inner_filter = combiner ? { combiner => too_deep } : too_deep

            expect {
              scope_sql(
                { audio_events: { operator => { taggings: { operator => inner_filter } } } },
                model: AudioRecording
              )
            }.to raise_error(
              CustomErrors::FilterArgumentError,
              /The `verifications` scope is nested too deeply, the maximum scope depth is 2/
            )
          end
        end
      end
    end

    context 'with invalid association settings' do
      [:and, :or, :not, :eq, :all, :none, :any].each do |name|
        it "rejects an association name that collides with the reserved key `#{name}`" do
          allow(Verification).to receive(:arel_table).and_return(Arel::Table.new(name))

          expect {
            scope_sql({ id: { gt: 0 } })
          }.to raise_error(
            CustomErrors::FilterSettingsError,
            /The `#{name}` association name cannot be a reserved filter key/
          )
        end
      end
    end

    context 'with association names' do
      # audio_events_tags is the table name, taggings is the name used by the rest of the API
      [:audio_events_tags, :taggings].each do |name|
        it "builds the scope for the `#{name}` name" do
          sql = scope_sql({ name => { any: { tag_id: { eq: 5 } } } })

          expected = <<~SQL.squish
            SELECT "audio_events"."id"
            FROM "audio_events"
            WHERE EXISTS (SELECT 1 FROM "audio_events_tags"
              WHERE "audio_events"."id" = "audio_events_tags"."audio_event_id"
                AND ("audio_events_tags"."tag_id" = 5))
            ORDER BY "audio_events"."created_at" DESC
            LIMIT 25 OFFSET 0
          SQL

          comparison_sql(sql, expected)
        end

        it "resolves the associated field `#{name}.tag_id`" do
          sql = scope_sql({ "#{name}.tag_id": { eq: 5 } })

          expected = <<~SQL.squish
            SELECT "audio_events"."id"
            FROM "audio_events"
            WHERE "audio_events"."id" IN (
              SELECT "audio_events"."id"
              FROM "audio_events"
              LEFT OUTER JOIN "audio_events_tags" ON "audio_events"."id" = "audio_events_tags"."audio_event_id"
              WHERE "audio_events_tags"."tag_id" = 5)
            ORDER BY "audio_events"."created_at" DESC
            LIMIT 25 OFFSET 0
          SQL

          comparison_sql(sql, expected)
        end
      end

      # taggings is also a field on audio events; only a scope operator makes it a scope
      it 'filters the field when the value is not a scope' do
        sql = scope_sql({ taggings: { eq: nil } })

        expected = <<~SQL.squish
          SELECT "audio_events"."id"
          FROM "audio_events"
          WHERE (SELECT json_agg(row_to_json(taggings_inner))
            FROM (SELECT "audio_events_tags"."id", "audio_events_tags"."audio_event_id",
              "audio_events_tags"."tag_id", "audio_events_tags"."created_at", "audio_events_tags"."updated_at",
              "audio_events_tags"."creator_id", "audio_events_tags"."updater_id"
              FROM "audio_events_tags"
              WHERE "audio_events_tags"."audio_event_id" = "audio_events"."id") AS "taggings_inner") IS NULL
          ORDER BY "audio_events"."created_at" DESC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
      end

      it 'treats a value mixing a scope operator and a field condition as an invalid scope' do
        expect {
          scope_sql({ taggings: { any: {}, eq: nil } })
        }.to raise_error(CustomErrors::FilterArgumentError,
          /The `taggings` scope must have an operator, one of `any`, `none`, or `all`/)
      end

      # audio recordings reach taggings through audio events
      [:audio_events_tags, :taggings].each do |name|
        it "resolves the nested associated field `#{name}.tag_id`" do
          sql = scope_sql({ "#{name}.tag_id": { eq: 5 } }, model: AudioRecording)

          expected = <<~SQL.squish
            SELECT "audio_recordings"."id"
            FROM "audio_recordings"
            WHERE ("audio_recordings"."status" = 'ready')
              AND ("audio_recordings"."id" IN (
                SELECT "audio_recordings"."id"
                FROM "audio_recordings"
                LEFT OUTER JOIN "audio_events" ON "audio_recordings"."id" = "audio_events"."audio_recording_id"
                LEFT OUTER JOIN "audio_events_tags" ON "audio_events"."id" = "audio_events_tags"."audio_event_id"
                WHERE "audio_events_tags"."tag_id" = 5))
            ORDER BY "audio_recordings"."recorded_date" DESC
            LIMIT 25 OFFSET 0
          SQL

          comparison_sql(sql, expected)
        end
      end
    end

    context 'with an empty inner filter' do
      # The `AND (TRUE)` is redundant in these expressions but it makes the build
      # code generation simpler and more consistent with non-empty inner filters cases.
      {
        any: <<~SQL.squish,
          EXISTS (SELECT 1 FROM "verifications"
             WHERE "audio_events"."id" = "verifications"."audio_event_id" AND (TRUE))
        SQL
        none: <<~SQL.squish,
          NOT (EXISTS (SELECT 1 FROM "verifications"
              WHERE "audio_events"."id" = "verifications"."audio_event_id" AND (TRUE)))
        SQL
        all: <<~SQL.squish
          NOT (EXISTS (SELECT 1 FROM "verifications"
             WHERE "audio_events"."id" = "verifications"."audio_event_id" AND (TRUE) IS NOT TRUE))
        SQL
      }.each do |operator, predicate|
        it "accepts `#{operator}` and treats every associated row as matching" do
          filter_query = Filter::Query.new(
            {
              projection: { only: [:id] },
              filter: { verifications: { operator => {} } }
            },
            AudioEvent.with_discarded,
            AudioEvent,
            AudioEvent.filter_settings
          )

          expected = <<~SQL.squish
            SELECT "audio_events"."id"
            FROM "audio_events"
            WHERE #{predicate}
            ORDER BY "audio_events"."created_at" DESC
            LIMIT 25 OFFSET 0
          SQL

          comparison_sql(filter_query.query_full.to_sql.squish, expected)
        end
      end
    end

    context 'with inner boolean combiners (and `all` operator predicate distribution)' do
      # The all operator distributes inner predicates into multiple clauses
      # for performance reasons. See `Filter::Build#distribute_is_not`
      [
        [
          :and,
          { and: [{ creator_id: { eq: 14 } }, { confirmed: { eq: 'skip' } }] },
          <<~SQL.squish
            ((("verifications"."creator_id" = 14) IS NOT TRUE)
              OR (("verifications"."confirmed" = 'skip') IS NOT TRUE))
          SQL
        ],
        [
          :or,
          { or: [{ creator_id: { eq: 14 } }, { confirmed: { eq: 'skip' } }] },
          <<~SQL.squish
            ((("verifications"."creator_id" = 14) IS NOT TRUE)
              AND (("verifications"."confirmed" = 'skip') IS NOT TRUE))
          SQL
        ],
        [
          :not,
          { not: { confirmed: { eq: 'skip' } } },
          '("verifications"."confirmed" = \'skip\') IS NOT FALSE'
        ]
      ].each do |combiner, inner_filter, predicate|
        it "tests the complete #{combiner} predicate for an all scope" do
          sql = scope_sql({ verifications: { all: inner_filter } })

          expected = <<~SQL.squish
            SELECT "audio_events"."id"
            FROM "audio_events"
            WHERE NOT (EXISTS (SELECT 1 FROM "verifications"
              WHERE "audio_events"."id" = "verifications"."audio_event_id"
                AND #{predicate}))
            ORDER BY "audio_events"."created_at" DESC
            LIMIT 25 OFFSET 0
          SQL

          comparison_sql(sql, expected)
        end
      end

      it 'keeps an inner or grouped within an any scope' do
        sql = scope_sql({
          verifications: {
            any: {
              or: [{ creator_id: { eq: 14 } }, { confirmed: { eq: 'skip' } }]
            }
          }
        })

        expected = <<~SQL.squish
          SELECT "audio_events"."id"
          FROM "audio_events"
          WHERE EXISTS (SELECT 1 FROM "verifications"
            WHERE "audio_events"."id" = "verifications"."audio_event_id"
              AND (("verifications"."creator_id" = 14) OR ("verifications"."confirmed" = 'skip')))
          ORDER BY "audio_events"."created_at" DESC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
      end

      it 'counts a nullable predicate that is not true as a failure for all' do
        sql = scope_sql({ verifications: { all: { updater_id: { eq: 14 } } } })

        expected = <<~SQL.squish
          SELECT "audio_events"."id"
          FROM "audio_events"
          WHERE NOT (EXISTS (SELECT 1 FROM "verifications"
            WHERE "audio_events"."id" = "verifications"."audio_event_id"
              AND ("verifications"."updater_id" = 14) IS NOT TRUE))
          ORDER BY "audio_events"."created_at" DESC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
      end
    end

    context 'with associated fields inside a scope' do
      [:any, :none, :all].each do |operator|
        it "resolves tags.text against the same verification row for #{operator}" do
          sql = scope_sql({ verifications: { operator => { 'tags.text': { eq: 'koala' } } } })

          inner_predicate = <<~SQL.squish
            "verifications"."id" IN (
              SELECT "verifications"."id"
              FROM "verifications"
              LEFT OUTER JOIN "tags" ON "verifications"."tag_id" = "tags"."id"
              WHERE "tags"."text" = 'koala')
          SQL
          inner_predicate = "(#{inner_predicate})"
          inner_predicate = "#{inner_predicate} IS NOT TRUE" if operator == :all
          quantifier = operator == :any ? 'EXISTS' : 'NOT (EXISTS'
          extra_close_paren = operator == :any ? '' : ')'

          expected = <<~SQL.squish
            SELECT "audio_events"."id"
            FROM "audio_events"
            WHERE #{quantifier} (SELECT 1 FROM "verifications"
              WHERE "audio_events"."id" = "verifications"."audio_event_id"
                AND #{inner_predicate}#{extra_close_paren})
            ORDER BY "audio_events"."created_at" DESC
            LIMIT 25 OFFSET 0
          SQL

          comparison_sql(sql, expected)
        end
      end
    end

    context 'with multiple scopes and parent conditions' do
      it 'builds independent subqueries for two scopes on the same association' do
        sql = scope_sql({
          and: [
            { verifications: { any: { confirmed: { eq: 'correct' } } } },
            { verifications: { any: { confirmed: { eq: 'incorrect' } } } }
          ]
        })

        expected = <<~SQL.squish
          SELECT "audio_events"."id"
          FROM "audio_events"
          WHERE ((EXISTS (SELECT 1 FROM "verifications"
            WHERE "audio_events"."id" = "verifications"."audio_event_id"
              AND ("verifications"."confirmed" = 'correct')))
            AND (EXISTS (SELECT 1 FROM "verifications"
              WHERE "audio_events"."id" = "verifications"."audio_event_id"
                AND ("verifications"."confirmed" = 'incorrect'))))
          ORDER BY "audio_events"."created_at" DESC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
      end

      it 'keeps parent conditions outside the scope and resolves inner fields against the child' do
        sql = scope_sql({
          creator_id: { eq: 20 },
          verifications: { any: { creator_id: { eq: 14 } } }
        })

        expected = <<~SQL.squish
          SELECT "audio_events"."id"
          FROM "audio_events"
          WHERE ("audio_events"."creator_id" = 20)
            AND (EXISTS (SELECT 1 FROM "verifications"
              WHERE "audio_events"."id" = "verifications"."audio_event_id"
                AND ("verifications"."creator_id" = 14)))
          ORDER BY "audio_events"."created_at" DESC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
      end
    end

    it 'applies all conditions in an any scope to the same associated row' do
      filter_query = Filter::Query.new(
        {
          projection: { only: [:id] },
          filter: {
            verifications: {
              any: {
                creator_id: { eq: 14 },
                tag_id: { in: [5, 6] },
                confirmed: { eq: 'skip' }
              }
            }
          }
        },
        AudioEvent.with_discarded,
        AudioEvent,
        AudioEvent.filter_settings
      )

      expected = <<~SQL.squish
        SELECT "audio_events"."id"
        FROM "audio_events"
        WHERE EXISTS (SELECT 1 FROM "verifications"
          WHERE "audio_events"."id" = "verifications"."audio_event_id"
            AND (("verifications"."creator_id" = 14)
            AND ("verifications"."tag_id" IN (5, 6))
            AND ("verifications"."confirmed" = 'skip')))
        ORDER BY "audio_events"."created_at" DESC
        LIMIT 25 OFFSET 0
      SQL

      comparison_sql(filter_query.query_full.to_sql.squish, expected)
    end

    it 'applies all conditions to an all scope to the same associated row' do
      filter_query = Filter::Query.new(
        {
          projection: { only: [:id] },
          filter: {
            verifications: {
              all: {
                creator_id: { eq: 14 },
                tag_id: { in: [5, 6] },
                confirmed: { eq: 'skip' }
              }
            }
          }
        },
        AudioEvent.with_discarded,
        AudioEvent,
        AudioEvent.filter_settings
      )

      expected = <<~SQL.squish
        SELECT "audio_events"."id"
        FROM "audio_events"
        WHERE NOT (EXISTS (SELECT 1 FROM "verifications"
          WHERE "audio_events"."id" = "verifications"."audio_event_id"
            AND ((("verifications"."creator_id" = 14) IS NOT TRUE)
            OR (("verifications"."tag_id" IN (5, 6)) IS NOT TRUE)
            OR (("verifications"."confirmed" = 'skip') IS NOT TRUE))))
        ORDER BY "audio_events"."created_at" DESC
        LIMIT 25 OFFSET 0
      SQL

      comparison_sql(filter_query.query_full.to_sql.squish, expected)
    end

    it 'applies all conditions to a none scope to the same associated row' do
      filter_query = Filter::Query.new(
        {
          projection: { only: [:id] },
          filter: {
            verifications: {
              none: {
                creator_id: { eq: 14 },
                tag_id: { in: [5, 6] },
                confirmed: { eq: 'skip' }
              }
            }
          }
        },
        AudioEvent.with_discarded,
        AudioEvent,
        AudioEvent.filter_settings
      )

      expected = <<~SQL.squish
        SELECT "audio_events"."id"
        FROM "audio_events"
        WHERE NOT (EXISTS (SELECT 1 FROM "verifications"
          WHERE "audio_events"."id" = "verifications"."audio_event_id"
            AND (("verifications"."creator_id" = 14)
            AND ("verifications"."tag_id" IN (5, 6))
            AND ("verifications"."confirmed" = 'skip'))))
        ORDER BY "audio_events"."created_at" DESC
        LIMIT 25 OFFSET 0
      SQL

      comparison_sql(filter_query.query_full.to_sql.squish, expected)
    end

    context 'with correlated scope subqueries' do
      # The correlation must reference the outer "audio_events" row. An
      # uncorrelated subquery (like the deprecated dotted form's
      # `"audio_events"."id" IN (SELECT "audio_events"."id" FROM "audio_events" ...)`)
      # would select "audio_events" a second time.
      {
        any: <<~SQL.squish,
          EXISTS (SELECT 1 FROM "verifications"
            WHERE "audio_events"."id" = "verifications"."audio_event_id"
              AND ("verifications"."confirmed" = 'skip'))
        SQL
        none: <<~SQL.squish,
          NOT (EXISTS (SELECT 1 FROM "verifications"
            WHERE "audio_events"."id" = "verifications"."audio_event_id"
              AND ("verifications"."confirmed" = 'skip')))
        SQL
        all: <<~SQL.squish
          NOT (EXISTS (SELECT 1 FROM "verifications"
            WHERE "audio_events"."id" = "verifications"."audio_event_id"
              AND ("verifications"."confirmed" = 'skip') IS NOT TRUE))
        SQL
      }.each do |operator, predicate|
        it "correlates the #{operator} subquery to the outer audio_events row" do
          sql = scope_sql({ verifications: { operator => { confirmed: { eq: 'skip' } } } })

          expected = <<~SQL.squish
            SELECT "audio_events"."id"
            FROM "audio_events"
            WHERE #{predicate}
            ORDER BY "audio_events"."created_at" DESC
            LIMIT 25 OFFSET 0
          SQL

          comparison_sql(sql, expected)
          expect(sql.scan('FROM "audio_events"').size).to eq(1)
        end
      end

      it 'keeps the subquery correlated when the scope is inside an or' do
        sql = scope_sql({
          or: [
            { id: { gt: 0 } },
            { verifications: { none: { confirmed: { eq: 'skip' } } } }
          ]
        })

        expected = <<~SQL.squish
          SELECT "audio_events"."id"
          FROM "audio_events"
          WHERE (("audio_events"."id" > 0)
            OR (NOT (EXISTS (SELECT 1 FROM "verifications"
              WHERE "audio_events"."id" = "verifications"."audio_event_id"
                AND ("verifications"."confirmed" = 'skip')))))
          ORDER BY "audio_events"."created_at" DESC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
        expect(sql.scan('FROM "audio_events"').size).to eq(1)
      end

      it 'keeps the subquery correlated when the scope is inside a not' do
        sql = scope_sql({
          not: { verifications: { any: { confirmed: { eq: 'skip' } } } }
        })

        expected = <<~SQL.squish
          SELECT "audio_events"."id"
          FROM "audio_events"
          WHERE NOT (EXISTS (SELECT 1 FROM "verifications"
            WHERE "audio_events"."id" = "verifications"."audio_event_id"
              AND ("verifications"."confirmed" = 'skip')))
          ORDER BY "audio_events"."created_at" DESC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
        expect(sql.scan('FROM "audio_events"').size).to eq(1)
      end
    end

    context 'with nested scopes' do
      it 'correlates a nested scope to the row of the enclosing scope' do
        sql = scope_sql({
          taggings: {
            any: {
              tag_id: { in: [5, 6] },
              verifications: { none: { creator_id: { eq: 14 }, confirmed: { not_eq: 'skip' } } }
            }
          }
        })

        expected = <<~SQL.squish
          SELECT "audio_events"."id"
          FROM "audio_events"
          WHERE EXISTS (SELECT 1 FROM "audio_events_tags"
            WHERE "audio_events"."id" = "audio_events_tags"."audio_event_id"
              AND (("audio_events_tags"."tag_id" IN (5, 6))
              AND (NOT (EXISTS (SELECT 1 FROM "verifications"
                WHERE ("audio_events_tags"."audio_event_id" = "verifications"."audio_event_id")
                  AND ("audio_events_tags"."tag_id" = "verifications"."tag_id")
                  AND (("verifications"."creator_id" = 14) AND ("verifications"."confirmed" != 'skip')))))))
          ORDER BY "audio_events"."created_at" DESC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
      end

      it 'keeps each correlation outside IS NOT TRUE for nested all scopes' do
        sql = scope_sql({ taggings: { all: { verifications: { all: { confirmed: { eq: 'correct' } } } } } })

        expected = <<~SQL.squish
          SELECT "audio_events"."id"
          FROM "audio_events"
          WHERE NOT (EXISTS (SELECT 1 FROM "audio_events_tags"
            WHERE "audio_events"."id" = "audio_events_tags"."audio_event_id"
              AND EXISTS (SELECT 1 FROM "verifications"
                WHERE ("audio_events_tags"."audio_event_id" = "verifications"."audio_event_id")
                  AND ("audio_events_tags"."tag_id" = "verifications"."tag_id")
                  AND ("verifications"."confirmed" = 'correct') IS NOT TRUE)))
          ORDER BY "audio_events"."created_at" DESC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
      end

      it 'exposes a nested anti join when all combines a field and a scope with or' do
        sql = scope_sql({
          taggings: {
            all: {
              or: [
                { tag_id: { not_in: [5, 6] } },
                { verifications: { any: { creator_id: { eq: 14 }, confirmed: { not_eq: 'skip' } } } }
              ]
            }
          }
        })

        expected = <<~SQL.squish
          SELECT "audio_events"."id"
          FROM "audio_events"
          WHERE NOT (EXISTS (SELECT 1 FROM "audio_events_tags"
            WHERE "audio_events"."id" = "audio_events_tags"."audio_event_id"
              AND ((("audio_events_tags"."tag_id" IN (5, 6)) IS NOT FALSE)
              AND (NOT (EXISTS (SELECT 1 FROM "verifications"
                WHERE ("audio_events_tags"."audio_event_id" = "verifications"."audio_event_id")
                  AND ("audio_events_tags"."tag_id" = "verifications"."tag_id")
                  AND (("verifications"."creator_id" = 14) AND ("verifications"."confirmed" != 'skip'))))))))
          ORDER BY "audio_events"."created_at" DESC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
      end

      it 'accepts scopes nested to the maximum depth' do
        sql = scope_sql(
          { audio_events: { any: { verifications: { any: { creator_id: { eq: 14 } } } } } },
          model: AudioRecording
        )

        expected = <<~SQL.squish
          SELECT "audio_recordings"."id"
          FROM "audio_recordings"
          WHERE ("audio_recordings"."status" = 'ready')
            AND (EXISTS (SELECT 1 FROM "audio_events"
              WHERE "audio_recordings"."id" = "audio_events"."audio_recording_id"
                AND (EXISTS (SELECT 1 FROM "verifications"
                  WHERE "audio_events"."id" = "verifications"."audio_event_id"
                    AND ("verifications"."creator_id" = 14)))))
          ORDER BY "audio_recordings"."recorded_date" DESC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
      end

      context 'when the maximum depth disallows nested scopes' do
        before { stub_const('Filter::Build::MAX_SCOPE_DEPTH', 1) }

        it 'rejects a nested scope' do
          expect {
            scope_sql({ taggings: { any: { verifications: { any: {} } } } })
          }.to raise_error(
            CustomErrors::FilterArgumentError,
            /The `verifications` scope is nested too deeply, the maximum scope depth is 1/
          )
        end

        it 'still accepts a scope that is not nested' do
          expect { scope_sql({ taggings: { any: {} } }) }.not_to raise_error
        end
      end
    end

    # taggings are joined to their verifications on both the event and the tag
    context 'with a composite association' do
      let(:correlation) do
        '("audio_events_tags"."audio_event_id" = "verifications"."audio_event_id") ' \
          'AND ("audio_events_tags"."tag_id" = "verifications"."tag_id")'
      end

      it 'correlates a scope on every joined column' do
        sql = scope_sql({ verifications: { none: { creator_id: { eq: 14 } } } }, model: Tagging)

        expected = <<~SQL.squish
          SELECT "audio_events_tags"."id"
          FROM "audio_events_tags"
          WHERE NOT (EXISTS (SELECT 1 FROM "verifications"
            WHERE #{correlation} AND ("verifications"."creator_id" = 14)))
          ORDER BY "audio_events_tags"."id" ASC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
      end

      it 'joins an associated field on every joined column' do
        sql = scope_sql({ 'verifications.creator_id': { eq: 14 } }, model: Tagging)

        expected = <<~SQL.squish
          SELECT "audio_events_tags"."id"
          FROM "audio_events_tags"
          WHERE "audio_events_tags"."id" IN (
            SELECT "audio_events_tags"."id"
            FROM "audio_events_tags"
            LEFT OUTER JOIN "verifications" ON #{correlation}
            WHERE "verifications"."creator_id" = 14)
          ORDER BY "audio_events_tags"."id" ASC
          LIMIT 25 OFFSET 0
        SQL

        comparison_sql(sql, expected)
      end
    end
  end
end
