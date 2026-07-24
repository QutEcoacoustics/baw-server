module BawWorkers
  module Dry
    # A Dry::Struct for when ordered attributes are needed.
    #
    # Attributes should be defined in the order they are expected to be returned by `ordered_values`.
    # Used by table resources in Camtrap Data Package exports, where the length and order of CSV row values must match
    # the table schema's field order for validation.
    class OrderedStruct < ::Dry::Struct
      # Return an array of attribute values in schema order, including nil values for optional attributes.
      # @return [Array]
      def ordered_values
        # Use attributes[key.name] over self[key.name] to safely return nil for missing keys, instead of Dry::Struct::MissingAttributeError.
        self.class.schema.map { |key| attributes[key.name] }
      end
    end
  end
end
