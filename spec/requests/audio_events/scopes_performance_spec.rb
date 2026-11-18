# frozen_string_literal: true

require_relative 'verification_states_helper'

# Before scopes, the only way to filter on an association was a dotted field (e.g. `verifications.creator_id`).
# Each dotted field builds its own uncorrelated `audio_events.id IN (SELECT ...)` subquery.
# The comment above each expectation is how long the closest filter using the old syntax took on this data.
# Some old filters time out: when a negated subquery's results don't fit in work_mem, Postgres re-scans them for
# every event.
# Each threshold is the time the scoped filter took plus 33%.
# Times are the mean of five requests after a warm-up, with JIT off (see before_all) and Postgres' default 4MB
# work_mem.
# The old syntax can't relate conditions to the same tagging or verification, so the old filters were only
# approximations and often found the wrong events.
describe 'Filtering AudioEvents by Verification states performance:', :slow do
  # Ten rows picked from the truth table in verification_states_spec.rb, so the copies have a mix of tags and
  # verifications. The names and expected events match that spec, so results can be cross-checked there.
  def self.truth_table = <<~TABLE
    | event | t1 | t2 | t3 ‖ u1:t1 | u1:t2 | u1:t3 ‖ u2:t1 | u2:t2 | u2:t3 ‖
    | a1    | x  | x  |    ‖ C     | C     |       ‖       |       | C     ‖
    | a5    |    |    |    ‖       |       |       ‖       |       |       ‖
    | a11   | x  |    |    ‖       |       |       ‖       |       |       ‖
    | a18   | x  |    |    ‖ C     |       |       ‖ I     |       |       ‖
    | a35   | x  |    |    ‖ S     |       |       ‖ S     |       |       ‖
    | a44   |    | x  |    ‖       | C     |       ‖       | I     |       ‖
    | a53   | x  | x  | x  ‖       |       |       ‖       |       | S     ‖
    | a57   | x  |    | x  ‖       |       | S     ‖ C     |       |       ‖
    | a62   | x  | x  |    ‖ S     | C     |       ‖       |       |       ‖
    | a68   | x  | x  |    ‖       |       |       ‖ S     | C     |       ‖
  TABLE

  include_context 'with verification states'

  # 10 events copied 30k times is 300k audio events, 450k taggings, and 480k verifications.
  # That's enough for the planner to choose hash joins, and for the old filters to take two to five times as long as
  # the scoped ones, while keeping parallel queries within the database's shared memory.
  def copies = 30_000

  before_all do
    copy_events(events.values)

    # These tests measure the difference between the join strategies Postgres uses for the scoped and old filters.
    # JIT compilation is a wrinkle that gets in the way: compiling each complex query took 0.5-1s here, no matter how
    # many rows it read, which hid most of that difference.
    # Requests use the test's connection, and SET LOCAL lasts until before_all rolls back, so this only affects this
    # file.
    ActiveRecord::Base.connection.execute('SET LOCAL jit = off')
  end

  let(:me) { u1.id }

  # Copies each event, along with its taggings and verifications.
  def copy_events(sources)
    connection = ActiveRecord::Base.connection

    connection.execute(<<~SQL.squish)
      CREATE TEMPORARY TABLE audio_event_copies AS
      SELECT nextval(pg_get_serial_sequence('audio_events', 'id')) AS id, source.id AS source_id, copy
      FROM unnest(ARRAY[#{sources.map(&:id).join(', ')}]) AS source(id)
      CROSS JOIN generate_series(1, #{copies}) AS copy
    SQL

    # Each round of copies is a second older than the last, so like real events, the copies of different events are
    # interleaved when sorted by creation date (the order of the requested page).
    connection.execute(copy_rows_query(
      AudioEvent, 'id', created_at: "source.created_at - audio_event_copies.copy * INTERVAL '1 second'"
    ))
    # The foreign key checks for the copied taggings and verifications look up audio_events by id.
    # Postgres caches the plans for those checks, and the cached plans are a sequential scan if they were made while
    # the table was small. Analyzing the table invalidates the cached plans, so the checks use the primary key instead.
    connection.execute('ANALYZE audio_events')

    connection.execute(copy_rows_query(Tagging, 'audio_event_id'))
    connection.execute(copy_rows_query(Verification, 'audio_event_id'))
    # Autovacuum can't see uncommitted rows, so it never analyzes the seeds, including the small permission tables.
    # Without statistics the planner estimates that only a handful of events pass the permission checks, so it probes
    # each event's taggings one at a time instead of using hash joins.
    # Analyze every table so the planner has the statistics it would have in production.
    # ANALYZE normally estimates from a random sample of rows, which gave different plans (and timings) on each run.
    # Each table's sample size comes from its largest statistics target, so the maximum target on the ids makes
    # ANALYZE read every row, and the plans are the same every time. The maximum target on every column would do the
    # same, but planning with such large statistics took longer than running some of the queries.
    [AudioEvent, Tagging, Verification].each do |model|
      connection.execute("ALTER TABLE #{model.table_name} ALTER COLUMN id SET STATISTICS 10000")
    end
    connection.execute('ANALYZE')

    connection.execute('DROP TABLE audio_event_copies')

    expect(AudioEvent.count).to eq(sources.size * (copies + 1))
  end

  # Inserts a copy of each of the model's rows that belong to a copied audio event, with `event_id_column` set to the
  # copy's id. `overrides` are SQL expressions for columns that shouldn't be copied as is.
  def copy_rows_query(model, event_id_column, **overrides)
    columns = model.column_names - ['id', event_id_column]
    values = columns.map { |column| overrides.fetch(column.to_sym, "source.#{column}") }

    <<~SQL.squish
      INSERT INTO #{model.table_name} (#{event_id_column}, #{columns.join(', ')})
      SELECT audio_event_copies.id, #{values.join(', ')}
      FROM audio_event_copies
      JOIN #{model.table_name} source ON source.#{event_id_column} = audio_event_copies.source_id
    SQL
  end

  # Requests the first page, which also counts every matching event, so the filter is run over the whole table.
  def filter_events(filter)
    post '/audio_events/filter', params: { filter: }, **api_with_body_headers(u1_token)
  end

  def expect_total(expected_event_name_suffixes)
    expect_success
    expect_has_paging(page: 1, items: 25, total: expected_event_name_suffixes.size * (copies + 1))
  end

  context 'with a specific set of tags,' do
    context 'when finding events based on what I have verified' do
      it 'that I have not verified (or is labelled as skip)' do
        filter = {
          taggings: {
            any: {
              tag_id: { in: [t1.id, t2.id] },
              verifications: {
                none: {
                  creator_id: { eq: me },
                  confirmed: { not_eq: 'skip' }
                }
              }
            }
          }
        }

        filter_events(filter)
        expect_total([11, 35, 53, 57, 62, 68])

        # the closest non-scope filter was cancelled after 60s; this filter took 0.20s
        expect { filter_events(filter) }.to perform_under(0.27).sec.sample(5)
      end

      it 'that I have not been exposed to (no labels at all)' do
        filter = {
          taggings: {
            any: {
              tag_id: { in: [t1.id, t2.id] },
              verifications: {
                none: {
                  creator_id: { eq: me }
                }
              }
            }
          }
        }

        filter_events(filter)
        expect_total([11, 53, 57, 68])

        # the closest non-scope filter takes 0.56s; this filter took 0.17s
        expect { filter_events(filter) }.to perform_under(0.24).sec.sample(5)
      end
    end

    context 'when filtering the campaign taggings (other useful filters)' do
      it 'where I have verified every campaign tag (excluding skips) (perfect completion)' do
        filter = {
          and: [
            { taggings: { any: { tag_id: { in: [t1.id, t2.id] } } } },
            {
              taggings: {
                all: {
                  or: [
                    { tag_id: { not_in: [t1.id, t2.id] } },
                    {
                      verifications: {
                        any: {
                          creator_id: { eq: me },
                          confirmed: { not_eq: 'skip' }
                        }
                      }
                    }
                  ]
                }
              }
            }
          ]
        }

        filter_events(filter)
        expect_total([1, 18, 44])

        # the closest non-scope filter takes 0.51s; this filter took 0.20s
        expect { filter_events(filter) }.to perform_under(0.27).sec.sample(5)
      end

      it 'where reviewers disagree about the same campaign tag' do
        filter = {
          taggings: {
            any: {
              tag_id: { in: [t1.id, t2.id] },
              and: [
                { verifications: { any: { confirmed: { eq: 'correct' } } } },
                { verifications: { any: { confirmed: { eq: 'incorrect' } } } }
              ]
            }
          }
        }

        filter_events(filter)
        expect_total([18, 44])

        # the closest non-scope filter takes 0.32s; this filter took 0.16s
        expect { filter_events(filter) }.to perform_under(0.21).sec.sample(5)
      end

      it 'where another user has verified a campaign tag and I still need to' do
        filter = {
          taggings: {
            any: {
              tag_id: { in: [t1.id, t2.id] },
              and: [
                {
                  verifications: {
                    any: {
                      creator_id: { not_eq: me },
                      confirmed: { not_eq: 'skip' }
                    }
                  }
                },
                {
                  verifications: {
                    none: {
                      creator_id: { eq: me },
                      confirmed: { not_eq: 'skip' }
                    }
                  }
                }
              ]
            }
          }
        }

        filter_events(filter)
        expect_total([57, 68])

        # the closest non-scope filter takes 0.83s; this filter took 0.18s
        expect { filter_events(filter) }.to perform_under(0.24).sec.sample(5)
      end

      it 'where all votes for a campaign tag are correct' do
        filter = {
          taggings: {
            any: {
              tag_id: { in: [t1.id, t2.id] },
              and: [
                { verifications: { any: {} } },
                { verifications: { all: { confirmed: { eq: 'correct' } } } }
              ]
            }
          }
        }

        filter_events(filter)
        expect_total([1, 57, 62, 68])

        # the closest non-scope filter takes 0.66s; this filter took 0.32s
        expect { filter_events(filter) }.to perform_under(0.43).sec.sample(5)
      end

      it 'where a campaign tag has only been skipped' do
        filter = {
          taggings: {
            any: {
              tag_id: { in: [t1.id, t2.id] },
              and: [
                { verifications: { any: { confirmed: { eq: 'skip' } } } },
                { verifications: { none: { confirmed: { not_eq: 'skip' } } } }
              ]
            }
          }
        }

        filter_events(filter)
        expect_total([35, 62, 68])

        # the closest non-scope filter was cancelled after 60s; this filter took 0.20s
        expect { filter_events(filter) }.to perform_under(0.27).sec.sample(5)
      end
    end
  end
end
