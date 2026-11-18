# frozen_string_literal: true

describe Filter::Query do
  include_context 'with a logger spy'

  def create_filter(params)
    Filter::Query.new(params, AudioEvent.all, AudioEvent, AudioEvent.filter_settings)
  end

  def deprecation_log_entries
    log_entries.select { |entry| entry[:message]&.include?('one-to-many relationships') }
  end

  context 'child association filtering' do
    # Filtering on one to many relationships is error prone.
    # See https://github.com/QutEcoacoustics/baw-server/issues/1076.
    # We're soft-deprecating this feature for now.
    it 'rejects invalid scopes' do
      # We're expecting a warning of deprecation for child association filtering
      # but not an error, yet.
      filter_query = Filter::Query.new(
        {
          filter: {
            'verifications.creator_id': { eq: 14 }
          }
        },
        AudioEvent.all,
        AudioEvent,
        AudioEvent.filter_settings
      )

      expect { filter_query.query_full }.not_to raise_error

      expect_log_entries_to_include(
        a_hash_including(
          level: 'warn',
          message: a_string_matching(/Filtering on one-to-many relationships is unpredictable and deprecated/i)
        )
      )
    end

    it 'reports the deprecated fields in the warning' do
      filter_query = create_filter(filter: { 'verifications.creator_id': { eq: 14 } })
      filter_query.query_full

      expect(filter_query.deprecations.compile_warning).to eq(
        'Filtering on one-to-many relationships is unpredictable and deprecated: `verifications.creator_id`.'
      )
    end

    it 'warns about dotted fields used inside a scope' do
      filter_query = create_filter(filter: { verifications: { any: { 'projects.id': { eq: 1 } } } })
      filter_query.query_full

      expect(filter_query.deprecations.compile_warning).to eq(
        'Filtering on one-to-many relationships is unpredictable and deprecated: `projects.id`.'
      )
    end

    it 'warns about projecting a child association' do
      filter_query = create_filter(projection: { only: [:id, :'verifications.creator_id'] })
      filter_query.query_full

      expect(filter_query.deprecations.compile_warning).to eq(
        'Projecting one-to-many relationships is unpredictable and deprecated: `verifications.creator_id`.'
      )
    end

    it 'warns about sorting by a child association' do
      filter_query = create_filter(sorting: { order_by: 'verifications.created_at', direction: 'asc' })
      filter_query.query_full

      expect(filter_query.deprecations.compile_warning).to eq(
        'Sorting by one-to-many relationships is unpredictable and deprecated: `verifications.created_at`.'
      )
    end

    it 'combines every usage into one warning, and only logs each field once' do
      filter_query = create_filter(
        filter: {
          'verifications.creator_id': { eq: 14 },
          or: {
            'verifications.creator_id': { eq: 15 },
            'taggings.tag_id': { eq: 1 }
          }
        },
        sorting: { order_by: 'verifications.created_at', direction: 'asc' }
      )
      filter_query.query_full

      expect(filter_query.deprecations.compile_warning).to eq(
        'Filtering on one-to-many relationships is unpredictable and deprecated: ' \
        '`verifications.creator_id`, `taggings.tag_id`. ' \
        'Sorting by one-to-many relationships is unpredictable and deprecated: `verifications.created_at`.'
      )
      expect(deprecation_log_entries).to contain_exactly(
        a_hash_including(level: 'warn', message: a_string_including('`verifications.creator_id`')),
        a_hash_including(level: 'warn', message: a_string_including('`taggings.tag_id`')),
        a_hash_including(level: 'warn', message: a_string_including('`verifications.created_at`'))
      )
    end

    it 'does not warn about associations that are not one-to-many' do
      filter_query = create_filter(
        filter: { 'audio_recordings.site_id': { eq: 1 } },
        projection: { only: [:id, :'audio_recordings.site_id'] },
        sorting: { order_by: 'audio_recordings.recorded_date', direction: 'asc' }
      )
      filter_query.query_full

      expect(filter_query.deprecations.compile_warning).to be_nil
      expect(deprecation_log_entries).to be_empty
    end
  end
end
