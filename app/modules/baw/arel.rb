# frozen_string_literal: true

module Baw
  # Our extensions to Arel.
  module Arel
    # Use the array function to create an array literal.
    # @return [Baw::Arel::Nodes::ArrayConstructor]
    def create_array(*expressions)
      Baw::Arel::Nodes::ArrayConstructor.new(expressions)
    end

    def seconds(seconds)
      Baw::Arel::Nodes::MakeInterval.new(seconds:)
    end

    # Create a COALESCE function node.
    # This exists because there is undesired functionality in ArelExtensions that
    # tries to get the type of the column from the db schema.
    # This fails for virtual tables (eg. CTEs) because they don't exist in the schema
    # causing very confusing errors (because it fails silently, the transaction fails
    # and not actual error is shown).
    # TODO: can we remove ArelExtensions entirely?
    # @return [::Arel::Nodes::Function]
    def coalesce(*expressions)
      ::Arel::Nodes::NamedFunction.new 'COALESCE', expressions
    end

    def wrap_value(value)
      return value if ::Arel.arel_node?(value)
      return nil if value.nil?

      ::Arel::Nodes::BindParam.new(value)
    end

    module NodeExtensions
      # Treat this node as an array.
      # Has no effect other than to allow array-like methods to be called on this node.
      # @return [Baw::Arel::Nodes::ArrayLike]
      def as_array
        Baw::Arel::Nodes::ArrayLike.new(self)
      end
    end

    module AttributeExtensions
      include NodeExtensions

      def unqualified
        ::Arel::Nodes::UnqualifiedColumn.new(self)
      end

      # Construct an interval from this attribute as if it were a number of seconds.
      # @return [Baw::Arel::Nodes::MakeInterval]
      def seconds
        Nodes::MakeInterval.new(seconds: self)
      end
    end

    module ExpressionsExtensions
      # Use the array aggregation function.
      # @return [Baw::Arel::Nodes::ArrayAgg]
      def array_agg
        Baw::Arel::Nodes::ArrayAgg.new([self])
      end

      def to_array
        Baw::Arel::Nodes::ArrayConstructor.new([self])
      end

      def seconds
        Nodes::MakeInterval.new(seconds: self)
      end

      # to_json conflicts with Ruby's to_json method
      def pg_to_json
        Baw::Arel::Nodes::ToJson.new([self])
      end

      def json_agg
        Baw::Arel::Nodes::JsonAgg.new([self])
      end

      def row_to_json
        Baw::Arel::Nodes::RowToJson.new([self])
      end
    end

    module ArrayFunctions
      # index into this array
      # @param index [Integer] the index to access - 0-based
      # @return [::Arel::Nodes::Subscript]
      def at(index)
        Baw::Arel::Nodes::Subscript.new(self, index)
      end

      # get the first element of this array
      # @return [::Arel::Nodes::Subscript]
      def first
        Baw::Arel::Nodes::Subscript.new(self, 0)
      end

      # slice this array
      # @param start [Integer, Range] the start index to access - 0-based
      #   or a range to access a slice.
      # @param length [Integer, nil] the length of the slice, if start is an Integer.
      # @return [::Arel::Nodes::ArrayLike]
      def slice(start, length = nil)
        case [start, length]
        in Integer, Integer
          Baw::Arel::Nodes::Subscript.new(self, start, start + length)
        in Integer, nil
          Baw::Arel::Nodes::Subscript.new(self, start)
        in Range, nil
          Baw::Arel::Nodes::Subscript.new(self, start.begin, start.end)
        else
          raise ArgumentError, 'start must be an Integer, and length must be an Integer or nil'
        end
      end

      def unnest
        Baw::Arel::Nodes::Unnest.new([self])
      end
    end
  end
end

# @!parse
#   ::Arel.extend(::Baw::Arel)
