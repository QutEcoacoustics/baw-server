# frozen_string_literal: true

describe Filter::Models::Association do
  subject(:association) { Filter::Models::Association.new(from_table:, to_table:, on:, available:) }

  let(:from_table) { AudioEvent.arel_table }
  let(:to_table) { Verification }
  let(:on) { from_table[:id].eq(to_table.arel_table[:audio_event_id]) }
  let(:available) { true }

  it 'represents a to-many child association' do
    expect(association.arity).to eq(:many)
    expect(association).to be_to_many
    expect(association).not_to be_to_one
    expect(association.names).to eq([:verifications])
    expect(association.joined_model).to eq(Verification)
    expect(association.joined_table).to eq(Verification.arel_table)
  end

  it 'preserves the correlation and availability in an immutable value' do
    expect(association.from_table).to eq(from_table)
    expect(association.on).to equal(on)
    expect(association.available).to be(true)
    expect(association).to be_frozen
  end

  it 'can be copied without overriding the derived arity' do
    copy = association.with(available: false)

    expect(copy.available).to be(false)
    expect(copy.arity).to eq(:many)
    expect(association.available).to be(true)
  end

  it 'exposes the joined column' do
    expect(association.joined_columns).to eq(['audio_event_id'])
  end

  it 'Uses the table_name for the association by default' do
    association = Filter::Models::Association.new(
      from_table: AudioEvent.arel_table, to_table: Tagging.arel_table,
      on: AudioEvent.arel_table[:id].eq(Tagging.arel_table[:audio_event_id]),
      available: true
    )

    expect(association.names).to eq([:audio_events_tags])
  end

  context 'with names' do
    subject(:association) { Filter::Models::Association.new(from_table:, to_table:, on:, available:, names:) }

    let(:to_table) { Tagging }
    let(:names) { [:audio_events_tags, :taggings] }

    it 'responds to every configured name' do
      expect(association.names).to eq([:audio_events_tags, :taggings])
      expect(association.names).to be_frozen
      expect(association.joined_table).to eq(Tagging.arel_table)
    end

    it 'treats the names as a complete list' do
      expect(association.with(names: [:taggings]).names).to eq([:taggings])
    end

    it 'falls back to the table name when names are nil' do
      expect(association.with(names: nil).names).to eq([:audio_events_tags])
    end

    it 'keeps the names when copied' do
      expect(association.with(available: false).names).to eq([:audio_events_tags, :taggings])
    end

    it 'derives the default name from to_table' do
      expect(Filter::Models::Association.default_name(Tagging)).to eq(:audio_events_tags)
      expect(Filter::Models::Association.default_name(Tagging.arel_table)).to eq(:audio_events_tags)
      expect(Filter::Models::Association.default_name('not a join')).to be_nil
    end

    [[], :taggings, 'taggings', ['taggings'], [:audio_events_tags, 'taggings'], [1], [nil]].each do |invalid_names|
      it "rejects invalid names #{invalid_names.inspect}" do
        expect { association.with(names: invalid_names) }.to raise_error(
          CustomErrors::FilterSettingsError, /Association `names` must be a non-empty array of symbols/
        )
      end
    end

    it 'rejects duplicate names' do
      expect { association.with(names: [:taggings, :taggings]) }.to raise_error(
        CustomErrors::FilterSettingsError, /Association `names` must be unique/
      )
    end

    it 'rejects a name that cannot be used as the prefix of a dotted field' do
      expect { association.with(names: [:'audio_events.tags']) }.to raise_error(
        CustomErrors::FilterSettingsError, /The `audio_events.tags` association name cannot contain a `.`/
      )
    end

    [:and, :or, :not, :eq, :all, :none, :any].each do |name|
      it "rejects the reserved name `#{name}`" do
        expect { association.with(names: [:audio_events_tags, name]) }.to raise_error(
          CustomErrors::FilterSettingsError, /The `#{name}` association name cannot be a reserved filter key/
        )
      end
    end
  end

  it 'defaults to a frozen empty associations array' do
    expect(association.associations).to eq([])
    expect(association.associations).to be_frozen
  end

  context 'with nested associations' do
    let(:grandchild) do
      Filter::Models::Association.new(
        from_table: Tag.arel_table, to_table: Tagging,
        on: Tag.arel_table[:id].eq(Tagging.arel_table[:tag_id]), available: true
      )
    end
    let(:child) do
      Filter::Models::Association.new(
        from_table: Verification.arel_table, to_table: Tag,
        on: Verification.arel_table[:tag_id].eq(Tag.arel_table[:id]), available: true,
        associations: [grandchild]
      )
    end
    let(:associations) { [child] }

    it 'preserves the hierarchy and from_table of each join' do
      parent = association.with(associations:)

      expect(parent.associations).to eq([child])
      expect(child.from_table).to eq(parent.joined_table)
      expect(child.associations).to eq([grandchild])
      expect(grandchild.from_table).to eq(child.joined_table)
    end

    it 'keeps arity local to each join' do
      expect(association.with(associations:)).to be_to_many
      expect(child).to be_to_one
      expect(grandchild).to be_to_many
    end

    it 'retains and freezes the caller array' do
      parent = association.with(associations:)

      expect(parent.associations).to equal(associations)
      expect(associations).to be_frozen
      expect(parent.associations).to eq([child])
      expect { associations.clear }.to raise_error(FrozenError)
    end

    it 'preserves children when copying the parent' do
      copy = association.with(associations:).with(available: false)

      expect(copy.associations).to eq([child])
      expect(copy.available).to be(false)
    end

    it 'rejects a child whose from_table is not the parent joined table' do
      expect { association.with(associations: [grandchild]) }.to raise_error(
        CustomErrors::FilterSettingsError, /Each child association's `from_table` must match the parent's joined table/
      )
    end

    it 'normalizes nil associations to an empty frozen array' do
      parent = association.with(associations: nil)

      expect(parent.associations).to eq([])
      expect(parent.associations).to be_frozen
    end

    [{}, [Verification]].each do |invalid_associations|
      it "rejects invalid associations #{invalid_associations.inspect}" do
        expect { association.with(associations: invalid_associations) }.to raise_error(
          CustomErrors::FilterSettingsError, /Association `associations` must be an array of Associations/
        )
      end
    end
  end

  context 'with a parent association' do
    let(:to_table) { AudioRecording }
    let(:on) { from_table[:audio_recording_id].eq(to_table.arel_table[:id]) }

    it 'recognizes the joined primary key as to-one' do
      expect(association.arity).to eq(:one)
      expect(association).to be_to_one
      expect(association).not_to be_to_many
    end
  end

  context 'with a reversed equality' do
    let(:on) { to_table.arel_table[:audio_event_id].eq(from_table[:id]) }

    it 'still classifies the joined side' do
      expect(association.arity).to eq(:many)
      expect(association.joined_columns).to eq(['audio_event_id'])
    end
  end

  context 'with a composite join' do
    let(:from_table) { Tagging.arel_table }
    let(:on) do
      from_table[:audio_event_id].eq(to_table.arel_table[:audio_event_id])
        .and(to_table.arel_table[:tag_id].eq(from_table[:tag_id]))
    end

    it 'exposes every joined column' do
      expect(association.equalities.size).to eq(2)
      expect(association.joined_columns).to eq(['audio_event_id', 'tag_id'])
    end

    # verifications are unique per audio_event_id, tag_id and creator_id
    it 'does not assume part of a composite unique key is unique' do
      expect(association.arity).to eq(:many)
    end

    it 'flattens nested and nodes' do
      equalities = on.children
      association = Filter::Models::Association.new(
        from_table:, to_table:, on: Arel::Nodes::And.new([Arel::Nodes::And.new(equalities)]), available:
      )

      expect(association.equalities).to eq(equalities)
    end

    context 'when the join covers a composite unique index' do
      let(:from_table) { Verification.arel_table }
      let(:to_table) { Tagging }

      # taggings are unique per audio_event_id and tag_id
      it 'recognizes the composite unique key as to-one' do
        expect(association.arity).to eq(:one)
      end
    end

    context 'when the join covers a composite primary key' do
      before do
        allow(ActiveRecord::Base.connection_pool.schema_cache)
          .to receive(:primary_keys).with('verifications').and_return(['audio_event_id', 'tag_id'])
      end

      it 'recognizes the composite primary key as to-one' do
        expect(association.arity).to eq(:one)
      end
    end
  end

  context 'with a bare join table' do
    let(:from_table) { Site.arel_table }
    let(:to_table) { Arel::Table.new(:projects_sites) }
    let(:on) { from_table[:id].eq(to_table[:site_id]) }
    let(:available) { false }

    it 'preserves unavailable join steps and classifies them as to-many' do
      expect(association.names).to eq([:projects_sites])
      expect(association.joined_model).to be_nil
      expect(association.joined_table).to eq(to_table)
      expect(association.available).to be(false)
      expect(association.arity).to eq(:many)
    end

    it 'retains children reached through an unavailable join table' do
      child = Filter::Models::Association.new(
        from_table: to_table, to_table: Project,
        on: to_table[:project_id].eq(Project.arel_table[:id]), available: true
      )
      parent = association.with(associations: [child])

      expect(parent.available).to be(false)
      expect(parent.associations).to eq([child])
      expect(child.from_table).to eq(parent.joined_table)
      expect(child).to be_to_one
    end
  end

  context 'with unique index metadata' do
    let(:index) do
      ActiveRecord::ConnectionAdapters::IndexDefinition.new(
        'verifications', 'test_index', true, ['audio_event_id']
      )
    end

    before do
      allow(ActiveRecord::Base.connection_pool.schema_cache)
        .to receive(:indexes).with('verifications').and_return([index])
    end

    it 'recognizes an unconditional single-column unique index' do
      expect(association.arity).to eq(:one)
    end

    context 'with an invalid index left by a failed concurrent build' do
      let(:index) do
        ActiveRecord::ConnectionAdapters::IndexDefinition.new(
          'verifications', 'test_index', true, ['audio_event_id'], valid: false
        )
      end

      it 'does not assume the joined column is unique' do
        expect(association.arity).to eq(:many)
      end
    end

    context 'with a partial index' do
      let(:index) do
        ActiveRecord::ConnectionAdapters::IndexDefinition.new(
          'verifications', 'test_index', true, ['audio_event_id'], where: "confirmed = 'correct'"
        )
      end

      it 'does not assume uniqueness outside the index predicate' do
        expect(association.arity).to eq(:many)
      end
    end

    context 'with a composite index' do
      let(:index) do
        ActiveRecord::ConnectionAdapters::IndexDefinition.new(
          'verifications', 'test_index', true, ['audio_event_id', 'tag_id']
        )
      end

      it 'does not assume the joined column alone is unique' do
        expect(association.arity).to eq(:many)
      end
    end

    context 'with a non-unique index' do
      let(:index) do
        ActiveRecord::ConnectionAdapters::IndexDefinition.new(
          'verifications', 'test_index', false, ['audio_event_id']
        )
      end

      it 'does not assume the joined column is unique' do
        expect(association.arity).to eq(:many)
      end
    end

    context 'with an expression index' do
      let(:index) do
        ActiveRecord::ConnectionAdapters::IndexDefinition.new(
          'verifications', 'test_index', true, '(audio_event_id + 1)'
        )
      end

      it 'does not assume the joined column is unique' do
        expect(association.arity).to eq(:many)
      end
    end
  end

  context 'with a composite primary key' do
    before do
      schema = ActiveRecord::Base.connection_pool.schema_cache
      allow(schema).to receive(:primary_keys).with('verifications').and_return(['audio_event_id', 'tag_id'])
      allow(schema).to receive(:indexes).with('verifications').and_return([])
    end

    it 'does not assume one part of the key is unique' do
      expect(association.arity).to eq(:many)
    end
  end

  context 'with invalid settings' do
    [:and, :or, :not, :eq, :all, :none, :any].each do |name|
      it "rejects the reserved joined name `#{name}` before checking the schema" do
        joined_table = Arel::Table.new(name)

        expect {
          Filter::Models::Association.new(
            from_table:, to_table: joined_table, on: from_table[:id].eq(joined_table[:id]), available:
          )
        }.to raise_error(
          CustomErrors::FilterSettingsError, /The `#{name}` association name cannot be a reserved filter key/
        )
      end
    end

    context 'with an invalid from_table' do
      let(:from_table) { AudioEvent }
      let(:on) { AudioEvent.arel_table[:id].eq(Verification.arel_table[:audio_event_id]) }

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association `from_table` must be an Arel::Table/
        )
      end
    end

    context 'with an invalid to_table' do
      let(:to_table) { Object }
      let(:on) { from_table[:id].eq(Verification.arel_table[:audio_event_id]) }

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association `to_table` must be an ActiveRecord model or an Arel::Table/
        )
      end
    end

    context 'with invalid availability' do
      let(:available) { nil }

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association `available` must be true or false/
        )
      end
    end

    context 'with a non-equality predicate' do
      let(:on) { from_table[:id].gt(Verification.arel_table[:audio_event_id]) }

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association on must be an equality between two column attributes/
        )
      end
    end

    context 'with a literal instead of a column' do
      let(:on) { from_table[:id].eq(1) }

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association on must be an equality between two column attributes/
        )
      end
    end

    context 'with an unrelated table' do
      let(:on) { AudioRecording.arel_table[:id].eq(Verification.arel_table[:audio_event_id]) }

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association `on` must join `from_table` to `to_table`/
        )
      end
    end

    context 'with an unaliased self join' do
      let(:to_table) { AudioEvent }
      let(:on) { from_table[:id].eq(from_table[:id]) }

      it 'rejects the ambiguous join direction' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association `on` must join `from_table` to `to_table`/
        )
      end
    end

    context 'with a missing joined column' do
      let(:on) { from_table[:id].eq(Verification.arel_table[:banana]) }

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association column `verifications.banana` does not exist/
        )
      end
    end

    context 'with a missing from_table column' do
      let(:on) { from_table[:banana].eq(Verification.arel_table[:audio_event_id]) }

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association column `audio_events.banana` does not exist/
        )
      end
    end

    context 'with an empty composite join' do
      let(:on) { Arel::Nodes::And.new([]) }

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association on must be an equality between two column attributes/
        )
      end
    end

    context 'with an or instead of an and' do
      let(:on) do
        from_table[:id].eq(Verification.arel_table[:audio_event_id])
          .or(from_table[:id].eq(Verification.arel_table[:tag_id]))
      end

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association on must be an equality between two column attributes/
        )
      end
    end

    context 'with a non-equality in a composite join' do
      let(:on) do
        from_table[:id].eq(Verification.arel_table[:audio_event_id])
          .and(from_table[:id].gt(Verification.arel_table[:tag_id]))
      end

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association on must be an equality between two column attributes/
        )
      end
    end

    context 'with an unrelated table in a composite join' do
      let(:on) do
        from_table[:id].eq(Verification.arel_table[:audio_event_id])
          .and(AudioRecording.arel_table[:id].eq(Verification.arel_table[:tag_id]))
      end

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association `on` must join `from_table` to `to_table`/
        )
      end
    end

    context 'with a missing column in a composite join' do
      let(:on) do
        from_table[:id].eq(Verification.arel_table[:audio_event_id])
          .and(from_table[:id].eq(Verification.arel_table[:banana]))
      end

      it 'raises a settings error' do
        expect { association }.to raise_error(
          CustomErrors::FilterSettingsError, /Association column `verifications.banana` does not exist/
        )
      end
    end
  end
end
