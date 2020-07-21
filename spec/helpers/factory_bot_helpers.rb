module Baw
  module FactoryBotHelpers
    # A custom factory bot helper method that generates attributes in
    # format suitable for sending as a JSON payload in a request spec.
    # Relies on the given model having a factory of the same name
    # and also having a schema method defined on it's class if the
    # schema parameter is not provided.
    # The schema parameter must be a hash of a json-schema-style structure.
    def body_attributes_for(model_name, schema: nil)
      schema = model_name.to_s.classify.constantize.schema if schema.nil?
      full = attributes_for(model_name)
      writeable =
        schema[:properties]
        .reject { |_key, value| value[:readOnly] }
        .keys
      partial = full.slice(*writeable)
      { model_name => partial }
    end
  end
end
