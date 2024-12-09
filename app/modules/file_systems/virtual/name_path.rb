# frozen_string_literal: true

module FileSystems
  class Virtual
    TO_INT = ->(value) { value.to_i_strict }.freeze
    TO_S = ->(value) { value.to_s }.freeze
    # A tuple of:
    # - name: the name of the virtual item
    # - path: the path fragment to the virtual item. If `nil`, `:id` is used.
    # - coerce: a proc to coerce the path parameter to the correct type
    # - condition: a proc to generate a condition to filter the model by the path
    # - projection_condition: a proc to modify the name/path projection. the first
    #   argument is the expression to project. It should be wrapped and returned.
    #   The second argument is a symbol of either `:name` or `:path` to indicate
    #   which part of the projection is being modified.
    #   This is useful for adding a prefix to a path, or for alternate names that are
    #   not part valid for every record (returning NULL/nil exclude an item from the
    #   Entry list).
    NamePath = Data.define(:name, :path, :coerce, :condition, :projection_wrapper) {
      def initialize(name:, path:, coerce: TO_INT, condition: nil, projection_wrapper: nil)
        condition ||= ->(value) { path.eq(value) }
        super(name:, path:, coerce:, condition:, projection_wrapper:)
      end

      # Normalizes an alternate name path to a Virtual::NamePath
      # @param alt [Symbol, Virtual::NamePath]
      # @return [Virtual::NamePath]
      def self.normalize(model, alt)
        case alt
        in Symbol
          NamePath.new(model.arel_table[alt], model.arel_table[:id], TO_INT)
        in ::Arel::Nodes::Node
          NamePath.new(alt, model.arel_table[:id], TO_INT)
        in NamePath
          alt
        else
          raise ArgumentError, 'alternates must be an symbol, arel node, or NamePath'
        end
      end
    }
  end
end
