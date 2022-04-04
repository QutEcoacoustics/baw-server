# frozen_string_literal: true

RSpec.shared_examples 'a model with a temporal stats bucket' do |options|
  has_other_relation = !options[:parent_factory].nil?

  let(:model) { options[:model] }
  let(:parent_factory) { options[:parent_factory] }
  let(:parent) { send(options[:parent]) }
  let(:other_key) { options[:other_key] }

  context 'when creating records' do
    let!(:default) {
      if has_other_relation
        model.create!(
          other_key => parent.id
        )
      else
        model.create!
      end
    }

    it 'the correct default bucket value is used' do
      expect(default.bucket).to eq(Date.today...(Date.today + 1.day))
    end

    model = options[:model]
    pks = defined?(model.primary_keys) ? model.primary_keys : [model.primary_key]
    options[:model].columns.each do |column|
      next if column.name == 'id'
      next if pks.include?(column.name)

      it "has defaults set for the #{column.name} stats columns" do
        expect(default.send(column.name)).to eq 0
      end
    end

    if has_other_relation
      context 'with compound relations' do
        it 'allows other records to have the same bucket' do
          second_parent = create(parent_factory)
          second = model.create!(
            other_key => second_parent.id
          ).reload

          expect(second.bucket).to eq(Date.today...(Date.today + 1.day))
        end

        it 'allows other records to have overlapping buckets' do
          second_parent = create(parent_factory)
          bucket = ((Date.today.to_datetime + 0.5.day)...(Date.today.to_datetime + 1.day + 0.5.day))
          second = model.create!(
            other_key => second_parent.id,
            bucket:
          )
          expect(second.bucket).to eq(bucket)
        end
      end
    end

    it 'allows a custom bucket to be set' do
      # April 5th 2063, Zephram Cochrane made fist contact with the Vulcans
      if has_other_relation
        second_parent = create(parent_factory)
        second = model.create!(
          other_key => second_parent.id,
          bucket: (Date.new(2063, 4, 5)...Date.new(2063, 4, 6))
        ).reload
      else
        second = model.create!(
          bucket: (Date.new(2063, 4, 5)...Date.new(2063, 4, 6))
        ).reload
      end

      expect(second.bucket).to eq((Date.new(2063, 4, 5)...Date.new(2063, 4, 6)))
    end
  end

  context 'with bad records' do
    it 'will fail with no bucket' do
      # active record knows the column is NOT NULL with a default value
      # you have to try really hard to outsmart it.
      # This test is testing the primary key is as we expect and is still valid.
      expect {
        table = model.arel_table
        insert = Arel::InsertManager.new
        insert.into table
        insert.columns  << table[other_key] if has_other_relation
        insert.columns  << table[:bucket]

        if has_other_relation
          [parent.id, Arel::Nodes::SqlLiteral.new('NULL')]
        else
          [Arel::Nodes::SqlLiteral.new('NULL')]
        end => values

        insert.values = insert.create_values(values)

        ActiveRecord::Base.connection.execute(insert.to_sql)
      }.to raise_error(
        ActiveRecord::NotNullViolation,
        /null value in column "bucket" of relation ".*" violates not-null constraint/
      )
    end

    if has_other_relation
      it 'will fail with null as the other key' do
        expect {
          model.create!(
            other_key => nil
          )
        }.to raise_error(ActiveRecord::RecordInvalid, /Validation failed: .* must exist/)
      end

      it 'does not duplicate records (with other relations)' do
        model.create!(other_key => parent.id)

        expect {
          model.create!(other_key => parent.id)
        }.to raise_error(ActiveRecord::RecordNotUnique,
          /PG::UniqueViolation.*violates unique constraint*/)

        expect(model.count).to eq 1
      end
    else
      it 'does not duplicate records (with no other relation)' do
        model.create!

        expect {
          model.create!
        }.to raise_error(ActiveRecord::RecordNotUnique,
          /PG::UniqueViolation.*violates unique constraint*/)

        expect(model.count).to eq 1
      end
    end
  end
end
