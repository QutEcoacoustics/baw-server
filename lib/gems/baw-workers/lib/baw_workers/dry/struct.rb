module BawWorkers
  module Dry
    module Struct
      # Return an array of schema values in attribute order, including nil values.
      # Used for csv export where length and order of values must match the header row.
      # @return [Array]
      def full_values
        # Use attributes[key.name] over self[key.name] to safely return nil for missing keys, instead of Dry::Struct::MissingAttributeError.
        self.class.schema.map { |key| attributes[key.name] }
      end
    end
  end
end
