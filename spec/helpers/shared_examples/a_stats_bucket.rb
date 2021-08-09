# frozen_string_literal: true

RSpec.shared_examples 'a model with a temporal stats bucket' do |options|
  other_key_supports_null = options[:model].columns_hash[options[:other_key].to_s].null
  let(:model) { options[:model] }
  let(:parent_factory) { options[:parent_factory] }
  let(:parent) { send(options[:parent]) }
  let(:other_key) { options[:other_key] }

  context 'when creating records' do
    let!(:default) {
      model.create!(
        other_key => parent.id
      )
    }

    it 'the correct default bucket value is used' do
      expect(default.bucket).to eq(Date.today...(Date.today + 1.day))
    end

    options[:model].columns.each do |column|
      next if column.name == 'id'
      next if options[:model].primary_keys.include?(column.name)

      it "has defaults set for the #{column.name} stats columns" do
        expect(default.send(column.name)).to eq 0
      end
    end

    it 'allows other records to have the same bucket' do
      second_parent = FactoryBot.create(parent_factory)
      second = model.create!(
        other_key => second_parent.id
      ).reload

      expect(second.bucket).to eq(Date.today...(Date.today + 1.day))
    end

    it 'allows other records to have overlapping buckets' do
      second_parent = FactoryBot.create(parent_factory)
      bucket = ((Date.today.to_datetime + 0.5.day)...(Date.today.to_datetime + 1.day + 0.5.day))
      second = model.create!(
        other_key => second_parent.id,
        bucket: bucket
      )
      expect(second.bucket).to eq(bucket)
    end

    it 'allows a custom bucket to be set' do
      # April 5th 2063, Zefram Cochrane made fist contact with the Vulcans
      second_parent = FactoryBot.create(parent_factory)
      second = model.create!(
        other_key => second_parent.id,
        bucket: (Date.new(2063, 4, 5)...Date.new(2063, 4, 6))
      ).reload

      expect(second.bucket).to eq((Date.new(2063, 4, 5)...Date.new(2063, 4, 6)))
    end

    if other_key_supports_null
      it 'accept a null as the other key' do
        result = model.create!(
          other_key => nil
        )

        expect(result.user_id).to eq nil
      end
    end
  end

  context 'with bad records' do
    unless other_key_supports_null
      it 'will fail with null as the other key' do
        expect {
          model.create!(
            other_key => nil
          )
        }.to raise_error(ActiveRecord::RecordInvalid, 'Validation failed: Audio recording must exist')
      end
    end

    it 'will fail with no bucket' do
      # active record knows the column is NOT NULL with a default value
      # you have to try really hard to outsmart it.
      # This test is testing the primary key is as we expect and is still valid.
      expect {
        table = model.arel_table
        insert = Arel::InsertManager.new
        insert.into table
        insert.columns  << table[other_key]
        insert.columns  << table[:bucket]

        insert.values = insert.create_values(
          [parent.id, Arel::Nodes::SqlLiteral.new('NULL')]
        )

        ActiveRecord::Base.connection.execute(insert.to_sql)
      }.to raise_error(
        ActiveRecord::NotNullViolation,
        /null value in column "bucket" violates not-null constraint/
      )
    end

    it 'will fail with duplicate buckets' do
      model.create!(other_key => parent.id)
      expect {
        model.create!(other_key => parent.id)
      }.to raise_error(
        ActiveRecord::StatementInvalid,
        /PG::ExclusionViolation.*conflicts with existing key \(#{other_key}, bucket\)/m
      )
    end

    it 'will fail with overlapping buckets' do
      model.create!(
        other_key => parent.id
      )

      expect {
        model.create!(
          other_key => parent.id,
          bucket: ((Date.today.to_datetime + 0.5.day)...(Date.today.to_datetime + 1.day + 0.5.day))
        )
      }.to raise_error(
        ActiveRecord::StatementInvalid,
        /PG::ExclusionViolation.*conflicts with existing key \(#{other_key}, bucket\)/m
      )
    end
  end
end
