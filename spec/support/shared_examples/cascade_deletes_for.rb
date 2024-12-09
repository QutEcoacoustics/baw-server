# frozen_string_literal: true

# Shared examples for testing cascade deletes.
# Instance name is a symbol for the instance to be deleted, defined in a let.
#
# Cascade graph is an hash of hashes - tree. Each symbol represents an association to be followed.
# Use nil or a symbol to indicate a leaf.
# example:
# cascade_graph = { sites: {audio_recordings: {audio_events: nil]} } }
RSpec.shared_examples 'cascade deletes for' do |instance_name, cascade_graph|
  raise 'instance_name must be a symbol' unless instance_name.is_a?(Symbol)
  raise 'cascade_graph must be an hash' unless cascade_graph.is_a?(Hash)

  # @param [ApplicationRecord] instance
  # @param [Array] cascade_graph
  # @return [Hash<Class, Array<Integer>>] A list of classes and arrays of ids that were reached by
  #   following the cascade_graph.
  def fetch_items(instance, _cascade_graph)
    raise 'instance must be an ApplicationRecord' unless instance.is_a?(ApplicationRecord)

    ([instance] + recurse_fetch(instance, cascade_graph)).uniq
  end

  def recurse_fetch(node, cascade_graph)
    case cascade_graph
    in Hash
      # a hash represents an association which itself has associations
      cascade_graph
        .flat_map { |key, value|
          # the key is the first association
          children = recurse_fetch(node, key)
          # then these children are the new nodes from which to continue
          children.concat(children.flat_map { |child|
            recurse_fetch(child, value)
          })
        }
        .compact
    in Symbol
      # invoke model association
      children = fetch_associated(node, cascade_graph)
      if children.empty?
        raise "No records found for relation `#{cascade_graph}` on #{node.class} with id `#{node.id}`. This is not a valid test of cascade delete unless all associations are populated with children."
      end

      children
    in nil
      nil
    else
      raise "Unexpected type `#{cascade_graph&.class}` in cascade graph: `#{cascade_graph}`"
    end
  end

  def fetch_associated(instance, association)
    reflection = instance.association(association).reflection

    if reflection.nil?
      raise "Association #{association} not found on #{instance.class}. " \
            "Available associations: #{instance.class.reflect_on_all_associations.map(&:name).join(', ')}"
    end

    klass = reflection.klass
    discardable = klass.try(:discardable?)

    case reflection
    in ActiveRecord::Reflection::HasManyReflection | ActiveRecord::Reflection::HasOneReflection if !discardable
      instance.send(association)
    in ActiveRecord::Reflection::HasManyReflection if discardable
      instance.send(association).with_discarded
    in ActiveRecord::Reflection::HasOneReflection if discardable
      klass.with_discarded.find_by(reflection.foreign_key => instance.id)
    in ActiveRecord::Reflection::BelongsToReflection
      raise 'BelongsToReflection is not supported for cascade deletes'
    else
      raise "Unexpected reflection type #{reflection.class} for association #{association}"
    end => result

    Array(result).compact
  end

  # @return Hash<string, integer> A hash of table names and their row counts.
  # A special key `'total'`` is the sum of all row counts.
  def total_row_counts_for_all_tables
    tables = ActiveRecord::Base.connection.tables

    query = tables
      .map { |table| "SELECT COUNT(*) FROM #{table}" }
      .join(' UNION ALL ')

    total = 0
    table_counts = {}
    ActiveRecord::Base.connection.execute(query).each_with_index do |row, i|
      count = row['count'].to_i
      total += count
      table_counts[tables[i]] = count
    end

    table_counts['total'] = total

    table_counts
  end

  def assert_expected_counts(counts, new_counts, items)
    before_total = counts['total']
    after_total = new_counts['total']

    expected_total = before_total - items.size

    expect(after_total).to(eq(expected_total), lambda {
      keys = counts.keys.to_set + new_counts.keys.to_set
      longest_key = keys.max_by(&:length).length

      table_header = "#{'Table'.ljust(longest_key)}\tBefore\tAfter\tExpected\n"
      keys.reduce(table_header) do |message, table|
        before = counts.fetch(table, 0)
        after = new_counts.fetch(table, 0)

        expected = before - items.count { |item| item.class.table_name == table }
        delta =  expected == after ? '' : ' ⬅️'
        message + "#{table.ljust(longest_key)}\t#{before}\t#{after}\t#{expected}#{delta}\n"
      end => table_message

      <<~MSG
        Expected the total number of rows to decrease by the number of related items for #{instance_name}.
        Related items: #{items.size}
        Before: #{before_total}
        After: #{after_total}
        Expected: #{expected_total}
        Discrepancy: #{after_total - expected_total}
        ---
        #{table_message}
      MSG
    })
  end

  let(:cascade_graph) { cascade_graph }
  let(:instance_name) { instance_name }

  let(:instance) { send(instance_name) }

  around do |example|
    # Bullet is useful but it is a distraction for these tests.
    Bullet.enable = false
    example.run
    Bullet.enable = true
  end

  stepwise instance_name do
    step 'first we count all rows' do
      @counts = total_row_counts_for_all_tables
    end

    step 'then we find all related items' do
      @items = fetch_items(instance, cascade_graph)
    end

    step 'then we delete the instance' do
      instance.destroy!
    end

    step 'then we count all rows again' do
      @new_counts = total_row_counts_for_all_tables
    end

    step 'then we check that the total number of items has decreased by the number of related items' do
      assert_expected_counts(@counts, @new_counts, @items)
    end

    step 'then we check that the related items are gone' do
      @items.each do |item|
        expect {
          item.reload
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
