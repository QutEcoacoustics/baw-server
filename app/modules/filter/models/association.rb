# frozen_string_literal: true

module Filter
  module Models
    # A directed join from `from_table` to `to_table`, an associated model or join table.
    # Nested associations continue from the joined table.
    # `on` is a column equality, or an `and` of column equalities for a composite join.
    # Arity describes how many joined rows can match one `from_table` row for this hop.
    # `names` are the names this association responds to in the public surface of the API:
    # scope keys and the prefix of dotted field names. They default to the joined table name.
    # When names are given, the list is complete: include the table name to keep it working.
    Association = Data.define(:from_table, :to_table, :on, :available, :associations, :names) {
      # Called before the instance is initialized, so `to_table` has not been validated yet.
      # @return [Symbol, nil] the joined table name, or nil if `to_table` is invalid.
      def self.default_name(to_table)
        table = to_table.is_a?(Arel::Table) ? to_table : to_table.try(:arel_table)
        table&.name&.to_sym
      end

      def initialize(from_table:, to_table:, on:, available:, associations: [], names: nil) # rubocop:disable Metrics/ParameterLists
        super(
          from_table:, to_table:, on:, available:,
          associations: (associations || []).freeze,
          names: (names.nil? ? [self.class.default_name(to_table)] : names).freeze
        )

        validate_settings!
        validate_names!
        validate_on!
        validate_columns!
        validate_associations!
      end

      # The arel_table of `to_table`
      # @return [Arel::Table]
      def joined_table
        to_table.is_a?(Arel::Table) ? to_table : to_table.arel_table
      end

      # The model behind the join.
      # @return [ActiveRecord::Base,nil] nil if `to_table` was an AREL table.
      def joined_model
        to_table unless to_table.is_a?(Arel::Table)
      end

      # The column equalities that make up `on`.
      # @return [Array<Arel::Nodes::Node>]
      def equalities
        flatten_and(on)
      end

      # @return [Array<String>] The names of the columns we're joining to, in `on` order.
      def joined_columns
        equalities.map { |equality| joined_attribute(equality).name.to_s }
      end

      # Derived from database uniqueness constraints rather than stored, because
      # Data instances are frozen. The schema cache makes repeat lookups cheap.
      # @return [Symbol] :one or :many
      def arity
        unique_key?(schema_cache, joined_table.name, joined_columns) ? :one : :many
      end

      # Can at most one joined row match a `from_table` row?
      # @return [Boolean]
      def to_one?
        arity == :one
      end

      # Can multiple joined rows match a `from_table` row?
      # @return [Boolean]
      def to_many?
        arity == :many
      end

      private

      # The pool's schema cache is shared and only checks out a connection on a
      # cache miss (or never, when a schema cache dump is loaded).
      def schema_cache
        ActiveRecord::Base.connection_pool.schema_cache
      end

      def validate_settings!
        unless from_table.is_a?(Arel::Table)
          raise CustomErrors::FilterSettingsError, 'Association `from_table` must be an Arel::Table'
        end

        unless to_table.is_a?(Arel::Table) || (to_table.is_a?(Class) && to_table < ActiveRecord::Base)
          raise CustomErrors::FilterSettingsError,
            'Association `to_table` must be an ActiveRecord model or an Arel::Table'
        end

        return if [true, false].include?(available)

        raise CustomErrors::FilterSettingsError, 'Association `available` must be true or false'
      end

      def validate_names!
        unless names.is_a?(Array) && names.any? && names.all?(Symbol)
          raise CustomErrors::FilterSettingsError,
            'Association `names` must be a non-empty array of symbols'
        end

        raise CustomErrors::FilterSettingsError, 'Association `names` must be unique' if names.uniq.size != names.size

        names.each do |name|
          if Validate::RESERVED_NAMES.include?(name)
            raise CustomErrors::FilterSettingsError,
              "The `#{name}` association name cannot be a reserved filter key"
          end

          # dotted field names are split at the first `.` to find the association
          if name.to_s.include?('.')
            raise CustomErrors::FilterSettingsError,
              "The `#{name}` association name cannot contain a `.`"
          end
        end
      end

      def validate_on!
        unless equalities.any? && equalities.all? { |equality| column_equality?(equality) }
          raise CustomErrors::FilterSettingsError,
            'Association on must be an equality between two column attributes, or an `and` of such equalities'
        end

        return if from_table != joined_table && equalities.all? { |equality|
          from_attribute(equality).relation == from_table && joined_attribute(equality).relation == joined_table
        }

        raise CustomErrors::FilterSettingsError,
          'Association `on` must join `from_table` to `to_table`'
      end

      def validate_columns!
        schema = schema_cache
        equalities.flat_map { |equality| [equality.left, equality.right] }.each do |attribute|
          next if schema.columns_hash(attribute.relation.name).key?(attribute.name.to_s)

          raise CustomErrors::FilterSettingsError,
            "Association column `#{attribute.relation.name}.#{attribute.name}` does not exist"
        end
      end

      def validate_associations!
        unless associations.is_a?(Array) && associations.all?(Association)
          raise CustomErrors::FilterSettingsError, 'Association `associations` must be an array of Associations'
        end

        return if associations.all? { |association| association.from_table == joined_table }

        raise CustomErrors::FilterSettingsError,
          "Each child association's `from_table` must match the parent's joined table"
      end

      def flatten_and(node)
        return [node] unless node.is_a?(Arel::Nodes::And)

        node.children.flat_map { |child| flatten_and(child) }
      end

      def from_attribute(equality)
        equality.left.relation == from_table ? equality.left : equality.right
      end

      def joined_attribute(equality)
        equality.left.relation == from_table ? equality.right : equality.left
      end

      def column_equality?(node)
        node.is_a?(Arel::Nodes::Equality) &&
          node.left.is_a?(Arel::Attributes::Attribute) && node.right.is_a?(Arel::Attributes::Attribute)
      end

      # Only valid, unconditional constraints prove to-one arity. A unique key proves it when
      # the join constrains every column of the key, e.g. a composite key joined on all its columns.
      # Expression indexes have no column list, so they never prove it.
      def unique_key?(schema, table_name, columns)
        keys = [Array(schema.primary_keys(table_name))] + schema.indexes(table_name).filter_map { |index|
          index.columns if index.valid? && index.unique && index.where.nil? && index.columns.is_a?(Array)
        }

        keys.any? { |key| key.any? && (key - columns).empty? }
      end
    }
  end
end
