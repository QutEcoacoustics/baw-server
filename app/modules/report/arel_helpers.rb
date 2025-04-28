# frozen_string_literal: true

module Report
  module ArelHelpers
    module_function

    # A CTE abstraction for readability, e.g.,
    # `with(query.cte).from(query.table)`
    # compared to using `.left` method on Arel::Nodes::As to access a cte table:
    # `with(query).from(query.left)`
    ReportQuery = Data.define(:table, :cte)

    # Return a new instance of select manager
    def manager
      Arel::SelectManager.new
    end

    def json_build_object_from_hash(hash)
      # Convert hash to alternating array of keys and values
      # where keys are automatically quoted SQL literals
      params = hash.flat_map { |key, value|
        raise ArgumentError, 'key must be a symbol' unless key.is_a?(Symbol)

        accepted_values = [Arel::Nodes::Node, Arel::Attributes::Attribute]
        raise ArgumentError, 'value must be an Arel node or attribute' unless accepted_values.any? { |klass|
          value.is_a?(klass)
        }

        [
          Arel::Nodes::SqlLiteral.new("'#{key}'"),
          value
        ]
      }

      # Create the json_build_object function with the parameters
      Arel::Nodes::NamedFunction.new('json_build_object', params)
    end

    # Convenience function to create a CTE (Common Table Expression)
    # @param name [String] The name to use as the CTE table name
    # @param query [Arel::SelectManager] The query for the CTE
    # @return [Array] Table and CTE node
    def create_cte(name, query)
      # check that query is an Arel node
      # check if query inherits from Arel::Nodes
      raise ArgumentError, 'query must inherit from Arel::Expressions' unless query.is_a?(Arel::Expressions)

      table = Arel::Table.new(name)
      cte = Arel::Nodes::As.new(table, query)
      [table, cte]
    end

    # Aggregate distinct values for a field.
    # @param table [Arel::Table] The table to aggregate from
    # @param field [Symbol] The field to aggregate
    # @return [Arel::Nodes::NamedFunction] An aggregation node
    def aggregate_distinct(table, field)
      Arel::Nodes::NamedFunction.new(
        'ARRAY_AGG',
        [Arel::Nodes::SqlLiteral.new("DISTINCT #{table[field].name}")]
      )
    end

    # Creates a date range expression in SQL
    # @param start_expr [String] SQL expression for start time
    # @param end_expr [String] SQL expression for end time
    # @return [Arel::Nodes::SqlLiteral] SQL literal node
    def datetime_range_array(start_expr, end_expr)
      Arel.sql(
      <<~SQL.squish
        array_to_json(ARRAY[
           to_char(#{start_expr}, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
           to_char(#{end_expr}, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         ])
      SQL
    ).as('range')
    end
  end
end

module Baw
  module Arel
    # Low-level Arel node extensions used to construct a query abstract syntax tree.
    # Nodes in this class are used for upsert syntax expressions and other things.
    module Nodes
      class JsonBuildObject < ::Arel::Nodes::NamedFunction
        def initialize(expr)
          super('json_build_object', expr)
        end
      end
    end
  end
end

module Baw
  # Our extensions to Arel.
  module Arel
    module ExpressionsExtensions
      # Use the json_build_object function.
      # @return [Baw::Arel::Nodes::JsonBuildObject]
      def json_build_object
        Baw::Arel::Nodes::JsonBuildObject.new([self])
      end
    end
  end
end

def test
  verifications = Verification.arel_table
  verification_summary_table = Arel::Table.new(:verification_summary)
  verification_summary_query = Arel::SelectManager.new
    .project(
      verifications[:tag_id],
      verifications[:id].count
    ).from(verifications).group(verifications[:tag_id])

  verification_cte = Arel::Nodes::As.new(verification_summary_table, verification_summary_query)
  aliased = verification_summary_table.as('t')

  # Create proper key-value pairs for json_build_object
  node = Baw::Arel::Nodes::JsonBuildObject.new([Arel::Nodes::Quoted.new('verification_summary'), aliased.right])
  # Create the json_build_object function call with properly structured arguments

  Arel::SelectManager.new.with(verification_cte)
    .project(aliased[:tag_id].as('tag_id'))
    .project(node).as('summaries').from(aliased).to_sql
end
