# frozen_string_literal: true

module FactoryBotHelpers
  module Example
    # A custom factory bot helper method that generates attributes in
    # format suitable for sending as a JSON payload in a request spec.
    # Relies on the given model having a factory of the same name
    # and also having a schema method defined on it's class if the
    # schema parameter is not provided.
    # The schema parameter must be a hash of a json-schema-style structure.
    # @param factory - the name of a factory to use instead of model_name
    # @param subset - an array of properties to keep, further filtering on the schema's writeable properties
    def body_attributes_for(model_name, factory: nil, subset: nil, factory_args: {})
      schema = model_name.to_s.classify.constantize.schema
      # was using attributes_for here but it doesn't include associations!
      # full = attributes_for(model_name)
      full = build(factory || model_name, **(factory_args || {})).attributes.symbolize_keys
      writeable = schema[:properties]
                  .select { |_key, value| value.fetch(:readOnly, false) == false }
                  .keys

      partial = full.slice(*writeable, *subset)
      # further restrict results if subset supplied
      partial = partial.slice(*subset) unless subset.nil?
      { model_name => partial }
    end
  end
end
