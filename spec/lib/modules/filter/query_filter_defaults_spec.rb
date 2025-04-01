# frozen_string_literal: true

describe Filter::Query do
  create_entire_hierarchy

  include SqlHelpers::Example

  def compare_filter_sql(filter, sql_result)
    filter_query = create_filter(filter)
    comparison_sql(filter_query.query_full.to_sql, sql_result)
    filter_query
  end

  describe 'default filters' do
    context 'with no-op values' do
      [
        # backwards compatibility, a default filter is not required
        {},
        { filter: {} },
        { filter: nil },
        { filter: -> { {} } },
        { filter: -> {} }
      ].each do |defaults|
        it "does not apply defaults when given #{defaults}" do
          filter_settings = AudioRecording.filter_settings.dup
          default_hash = filter_settings[:defaults].except(:filter).merge(defaults)

          # should throw if invalid, this is the test
          filter = Filter::Query.new(
            {},
            AudioRecording.all,
            AudioRecording,
            filter_settings.merge(defaults: default_hash)
          )

          # and nothing has been applied
          expect(filter.filter).to eq({})

          expect(filter.query_without_paging_sorting.count('*')).to eq(AudioRecording.count)
        end
      end
    end

    context 'with incorrect configuration' do
      [
        1,
        [1],
        'hello',
        -> { 'hello' },
        -> { 1 },
        # we don't allow root arrays in the defaults
        # root arrays are just syntactic sugar for keyed "and" filters and the
        # merging implications are too complex to be worth it
        [{ id: { gt: 0 } }],
        -> { [{ id: { gt: 0 } }] }
      ].each do |default_filter|
        it 'requires a hash or an array of filters' do
          filter_settings = AudioRecording.filter_settings
          default = filter_settings[:defaults].merge(filter: default_filter)

          expect {
            Filter::Query.new(
              {},
              AudioRecording.all,
              AudioRecording,
              filter_settings.merge(defaults: default)
            ).query_full
          }.to raise_error(CustomErrors::FilterSettingsError, /Filter settings invalid: .*/)
        end
      end
    end

    shared_examples 'a filter with defaults' do |test_case|
      describe "test case #{test_case[:name]}:" do
        let(:default) { test_case[:default] }
        let(:supplied) { test_case[:supplied] }
        let(:expected) { test_case[:expected] }
        let(:expected_set) { test_case[:expected_set] }
        let(:where_clause) { test_case[:where_clause] }

        def filter_query(default_filter, supplied_params)
          filter_settings = AudioRecording.filter_settings
          defaults = filter_settings[:defaults].except(:filter)

          Filter::Query.new(
            { filter: supplied_params },
            AudioRecording.all,
            AudioRecording,
            filter_settings.merge(defaults: defaults.merge({ filter: default_filter }))
          )
        end

        it 'is applied' do
          expect(filter_query(default, supplied).filter).to eq(expected)
        end

        it 'is effectual' do
          result = filter_query(default, supplied).query_full.to_a
          if expected_set == :empty
            expect(result).to be_empty
          else
            expect(result).not_to be_empty
          end
        end

        it 'generates correct sql' do
          contains_sql(
            filter_query(default, supplied).query_full.to_sql,
            where_clause
          )
        end
      end
    end

    [
      {
        name: 'default filter',
        default: { id: { lt: 0 } },
        supplied: {},
        expected: { id: { lt: 0 } },
        expected_set: :empty,
        where_clause: '"audio_recordings"."id" < 0'
      },
      {
        name: 'default filter overridden by supplied filter',
        default: { id: { lt: 0 } },
        supplied: { id: { lt: 1_000_000 } },
        expected: { id: { lt: 1_000_000 } },
        where_clause: '"audio_recordings"."id" < 1000000'
      },

      {
        name: 'default filter merged with supplied filter (same field)',
        default: { id: { lt: 0 } },
        supplied: { id: { gt: 0 } },
        expected: { id: { lt: 0, gt: 0 } },
        expected_set: :empty,
        where_clause: '("audio_recordings"."id" < 0) AND ("audio_recordings"."id" > 0)'
      },
      {
        name: 'default filter merged with supplied filter (different fields)',
        default: { id: { lt: 0 } },
        supplied: { duration_seconds: { gt: 3600 } },
        expected: { id: { lt: 0 }, duration_seconds: { gt: 3600 } },
        expected_set: :empty,
        where_clause: '("audio_recordings"."id" < 0) AND ("audio_recordings"."duration_seconds" > 3600.0)'
      },
      {
        name: 'default filter removed by supplied filter',
        default: { id: { lt: 0 } },
        supplied: { id: nil },
        expected: {},
        where_clause: ''
      },
      {
        name: 'expression removal syntax when there is no expression to remove',
        default: { id: { lt: 0 } },
        supplied: { id: { lt: 0 }, duration_seconds: nil },
        expected: { id: { lt: 0 } },
        expected_set: :empty,
        where_clause: '("audio_recordings"."id" < 0)'
      },
      {
        name: 'default filter removed by supplied filter, with new expression',
        default: { id: { lt: 0 } },
        supplied: { id: nil, duration_seconds: { gt: 3600 } },
        expected: { duration_seconds: { gt: 3600 } },
        where_clause: '"audio_recordings"."duration_seconds" > 3600'
      },
      {
        name: 'merging array filters (same field)',
        default: { id: { lt: 0 } },
        supplied: [{ id: { gt: 0 } }],
        expected: { and: [{ id: { lt: 0 } }, { id: { gt: 0 } }] },
        expected_set: :empty,
        where_clause: '("audio_recordings"."id" < 0) AND ("audio_recordings"."id" > 0)'
      },
      {
        name: 'merging array filters (same field and operator)',
        default: { id: { lt: 0 } },
        supplied: [{ id: { lt: 10 } }],
        expected: { and: [{ id: { lt: 0 } }, { id: { lt: 10 } }] },
        expected_set: :empty,
        where_clause: '("audio_recordings"."id" < 0) AND ("audio_recordings"."id" < 10)'
      },
      {
        name: 'merging array filters (different fields)',
        default: { id: { lt: 0 } },
        supplied: [{ id: { gt: 0 } }, { duration_seconds: { gt: 3600 } }],
        expected: { and: [{ id: { lt: 0 } }, { id: { gt: 0 } }, { duration_seconds: { gt: 3600 } }] },
        expected_set: :empty,
        where_clause: '("audio_recordings"."id" < 0) AND ("audio_recordings"."id" > 0) AND ("audio_recordings"."duration_seconds" > 3600.0)'
      },
      {
        name: 'merging array filters: can remove default filter',
        default: { id: { lt: 0 } },
        supplied: [{ duration_seconds: { gt: 3600 } }, { id: nil }],
        expected: { and: [{ duration_seconds: { gt: 3600 } }] },
        where_clause: '"audio_recordings"."duration_seconds" > 3600'
      },
      {
        name: 'merging array filters: can remove default filter and add new filter',
        default: { id: { lt: 0 } },
        supplied: [{ id: nil }, { id: { lt: 1_000_000 } }],
        # 1-expression and automatically gets flattened
        expected: { and: [{ id: { lt: 1_000_000 } }] },
        where_clause: '"audio_recordings"."id" < 1000000'
      },
      {
        name: 'merging array filters: can add and remove expressions multiple times',
        default: { id: { lt: 0 } },
        supplied: [
          { duration_seconds: { gt: 3600 } },
          { id: { gt: -1 } },
          { id: nil },
          { id: { gt: 0 } },
          { id: { gt: 1 } },
          { id: nil }
        ],
        expected: { and: [{ duration_seconds: { gt: 3600 } }] },
        where_clause: '"audio_recordings"."duration_seconds" > 3600'
      },
      {
        name: 'merging filters: can remove and add _and_ expressions',
        default: { and: [{ id: { lt: 0 } }] },
        supplied: { and: nil, id: { gt: 0 } },
        expected: { id: { gt: 0 } },
        where_clause: '"audio_recordings"."id" > 0'
      },
      {
        name: 'merging filters: can remove and add _and_ expressions with multiple default expressions',
        default: { and: [{ id: { lt: 0 } }, { duration_seconds: { gt: 3600 } }] },
        supplied: { and: nil, id: { gt: 0 } },
        expected: { id: { gt: 0 } },
        where_clause: '"audio_recordings"."id" > 0'
      },
      {
        name: 'merging array filters: can remove _and_  multi values expressions',
        default: { and: [{ id: { lt: 0 } }, { duration_seconds: { gt: 3600 } }] },
        supplied: [{ and: nil }, { duration_seconds: { gt: 3600 } }],
        expected: { and: [{ duration_seconds: { gt: 3600 } }] },
        where_clause: '"audio_recordings"."duration_seconds" > 3600'
      }
    ].each do |test_case|
      it_behaves_like 'a filter with defaults', test_case
    end
  end
end
