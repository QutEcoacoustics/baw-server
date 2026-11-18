# frozen_string_literal: true

describe Filter::Build do
  subject(:build) { Filter::Build.new(model.arel_table, settings) }

  let(:model) { AudioRecording }
  let(:settings) { model.filter_settings.deep_dup }

  it 'constructs association structs from the configured joins' do
    associations = build.composed_associations
    audio_events = associations.find { |association| association.to_table == AudioEvent }

    expect(associations).to all(be_a(Filter::Models::Association))
    expect(audio_events.from_table).to eq(model.arel_table)
    expect(audio_events.on).to eq(settings[:valid_associations].first[:on])
    expect(audio_events.available).to be(true)
    expect(audio_events).to be_to_many
  end

  it 'caches the available associations' do
    expect(build.composed_associations).to equal(build.composed_associations)
    expect(build.composed_associations).to be_frozen
  end

  it 'preserves nested associations and their from_tables' do
    audio_events = build.composed_associations.find { |association| association.to_table == AudioEvent }
    taggings = audio_events.associations.first
    tags = taggings.associations.first

    expect(taggings.joined_model).to eq(Tagging)
    expect(taggings.from_table).to eq(audio_events.joined_table)
    expect(tags.joined_model).to eq(Tag)
    expect(tags.from_table).to eq(taggings.joined_table)
    expect(audio_events.associations).to be_frozen
  end

  it 'keeps unavailable join tables in the tree but excludes them from available fields' do
    associations = build.composed_associations
    sites = associations.find { |association| association.to_table == Site }
    projects_sites = sites.associations.find { |association| association.names.include?(:projects_sites) }
    projects = projects_sites.associations.first

    expect(projects_sites.available).to be(false)
    expect(projects_sites.joined_model).to be_nil
    expect(projects.from_table).to eq(projects_sites.joined_table)
    expect(projects.joined_model).to eq(Project)
    expect(associations).to include(projects)
    expect(associations).not_to include(projects_sites)
  end

  it 'resolves associated fields using the configured model' do
    info = build.parse_table_field(model.arel_table, :'projects.name')

    expect(info).to include(model: Project, arel_table: Project.arel_table, field_name: :name)
  end

  context 'with association names' do
    let(:model) { AudioEvent }

    it 'passes the configured names to the association' do
      taggings = build.composed_associations.find { |association| association.to_table == Tagging }

      expect(taggings.names).to eq([:audio_events_tags, :taggings])
    end

    [:audio_events_tags, :taggings].each do |name|
      it "resolves associated fields using the `#{name}` name" do
        info = build.parse_table_field(model.arel_table, :"#{name}.tag_id")

        expect(info).to include(model: Tagging, arel_table: Tagging.arel_table, field_name: :tag_id)
      end
    end

    it 'lists every name when rejecting an unknown associated field' do
      expect { build.parse_table_field(model.arel_table, :'banana.tag_id') }.to raise_error(
        CustomErrors::FilterArgumentError, /Name must be in \[.*:audio_events_tags, :taggings.*\], got banana/
      )
    end

    # scopes are recognized by their operator, so an association and a field can share a name
    it 'allows a name that is also a field' do
      expect(settings[:valid_fields]).to include(:taggings)
      expect { build }.not_to raise_error
    end

    context 'when the association is nested' do
      let(:model) { AudioRecording }

      it 'passes the configured names to the nested association' do
        taggings = build.composed_associations.find { |association| association.to_table == Tagging }

        expect(taggings.from_table).to eq(AudioEvent.arel_table)
        expect(taggings.names).to eq([:audio_events_tags, :taggings])
      end

      [:audio_events_tags, :taggings].each do |name|
        it "resolves associated fields using the `#{name}` name" do
          info = build.parse_table_field(model.arel_table, :"#{name}.tag_id")

          expect(info).to include(model: Tagging, arel_table: Tagging.arel_table, field_name: :tag_id)
        end
      end
    end
  end

  context 'with a composite association' do
    let(:model) { Tagging }

    it 'joins verifications on the event and the tag' do
      verifications = build.composed_associations.find { |association| association.to_table == Verification }

      expect(verifications.joined_columns).to eq(['audio_event_id', 'tag_id'])
      expect(verifications).to be_to_many
    end

    it 'resolves associated fields through the composite join' do
      info = build.parse_table_field(model.arel_table, :'verifications.creator_id')

      expect(info).to include(model: Verification, arel_table: Verification.arel_table, field_name: :creator_id)
    end
  end

  it 'reuses cached schema metadata without checking out a connection' do
    build
    pool = ActiveRecord::Base.connection_pool
    allow(pool).to receive(:with_connection).and_call_original

    Filter::Build.new(model.arel_table, settings)

    expect(pool).not_to have_received(:with_connection)
  end

  it 'rejects fields from unavailable join tables' do
    settings[:valid_associations].select! { |association| association[:join] == Site }

    expect { build.parse_table_field(model.arel_table, :'projects_sites.project_id') }.to raise_error(
      CustomErrors::FilterArgumentError, /Name must be in \[:regions, :projects, :sites\], got projects_sites/
    )
  end

  context 'without association settings' do
    before { settings.delete(:valid_associations) }

    it 'has no available associations' do
      expect(build.composed_associations).to eq([])
    end
  end

  context 'with nil association settings' do
    before { settings[:valid_associations] = nil }

    it 'has no available associations' do
      expect(build.composed_associations).to eq([])
    end
  end

  context 'with invalid association settings' do
    [false, {}, [nil]].each do |invalid_associations|
      it "rejects a malformed configuration #{invalid_associations.inspect}" do
        settings[:valid_associations] = invalid_associations

        expect { build }.to raise_error(
          CustomErrors::FilterSettingsError, /Association settings must be an array of hashes/
        )
      end
    end

    it 'validates nested configuration shapes' do
      settings[:valid_associations].first[:associations] = {}

      expect { build }.to raise_error(
        CustomErrors::FilterSettingsError, /Association settings must be an array of hashes/
      )
    end

    it 'delegates join validation to the struct' do
      settings[:valid_associations] = [{ join: Object, on: model.arel_table[:id].eq(1), available: true }]

      expect { build }.to raise_error(
        CustomErrors::FilterSettingsError, /Association `to_table` must be an ActiveRecord model or an Arel::Table/
      )
    end

    it 'delegates availability validation to the struct' do
      settings[:valid_associations].first[:available] = nil

      expect { build }.to raise_error(
        CustomErrors::FilterSettingsError, /Association `available` must be true or false/
      )
    end

    it 'validates column existence even on an unavailable join' do
      settings[:valid_associations] = [{
        join: Arel::Table.new(:projects_sites),
        on: model.arel_table[:id].eq(Arel::Table.new(:projects_sites)[:missing_column]),
        available: false
      }]

      expect { build }.to raise_error(
        CustomErrors::FilterSettingsError, /Association column `projects_sites.missing_column` does not exist/
      )
    end

    it 'validates the from_table of nested joins' do
      settings[:valid_associations].first[:associations].first[:on] =
        model.arel_table[:id].eq(Tagging.arel_table[:audio_event_id])

      expect { build }.to raise_error(
        CustomErrors::FilterSettingsError, /Association `on` must join `from_table` to `to_table`/
      )
    end
  end

  context 'when distributing the all scope truth test' do
    # See `Filter::Build#distribute_is_not` for documentation on how and
    # why this distribution is necessary for the `all` scope truth test.
    {
      'and' => ->(a, b) { a.and(b) },
      'or' => ->(a, b) { a.or(b) },
      'not and' => ->(a, b) { a.and(b).not },
      'not or' => ->(a, b) { a.or(b).not },
      'mixed combiners and double negation' => ->(a, b) { a.and(b.or(a.not)).not.not },
      'or with exists' => ->(a, b) { a.or(Arel::SelectManager.new.project(1).where(b).exists) },
      'not and with exists' => ->(a, b) { a.and(Arel::SelectManager.new.project(1).where(b).exists).not },
      'or with not exists' => ->(a, b) { a.or(Arel::SelectManager.new.project(1).where(b).exists.not) }
    }.each do |name, combine|
      it "preserves TRUE, FALSE and NULL combinations for #{name}" do
        a = Arel::Table.new(:a)[:value].eq(true)
        b = Arel::Table.new(:b)[:value].eq(true)
        predicate = combine.call(a, b)
        rewritten = build.send(:distribute_is_not, predicate)

        # This is the predicate before applying `distribute_is_not`,
        # which is the last part of
        #  `NOT EXISTS (SELECT 1 FROM association WHERE correlation AND (P) IS NOT TRUE)`
        original = Arel::Nodes::Grouping.new(predicate).is_not(Arel::Nodes::True.new)

        results = ActiveRecord::Base.connection.select_rows(<<~SQL.squish)
          SELECT #{rewritten.to_sql}, #{original.to_sql}
          FROM (VALUES (TRUE), (FALSE), (NULL::boolean)) AS a(value)
          CROSS JOIN (VALUES (TRUE), (FALSE), (NULL::boolean)) AS b(value)
        SQL

        # The test ensures that the rewritten predicate produced by `distribute_is_not`
        # behaves identically to the original predicate for all combinations of TRUE, FALSE, and NULL.
        expect(results.size).to eq(9)
        results.each { |actual, expected| expect(actual).to eq(expected) }
      end
    end
  end
end
