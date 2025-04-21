# frozen_string_literal: true

module Baw
  # Our extensions to Arel.
  module Arel
    # Use the array function to create an array literal.
    # @return [Baw::Arel::Nodes::ArrayConstructor]
    def create_array(*expressions)
      Baw::Arel::Nodes::ArrayConstructor.new(expressions)
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
    end

    module ExpressionsExtensions
      # Use the array aggregation function.
      # @return [Baw::Arel::Nodes::ArrayAgg]
      def array_agg
        Baw::Arel::Nodes::ArrayAgg.new([self])
      end

      # Use the array to json function.
      # @return [Baw::Arel::Nodes::ArrayToJson]
      def array_to_json
        Baw::Arel::Nodes::ArrayToJson.new([self])
      end

      def to_array
        Baw::Arel::Nodes::ArrayConstructor.new([self])
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
