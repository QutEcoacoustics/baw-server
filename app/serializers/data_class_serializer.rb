# frozen_string_literal: true

# ActiveJob argument serializer for the plain `DataClass::*` form objects.
#
# These objects are not ActiveRecord models, so they cannot be serialized via
# GlobalID. Classes that include `DataClass::Serializable` describe their own
# attributes, so this serializer simply delegates to them. This lets the form
# objects be passed as arguments to mailers delivered asynchronously with
# `deliver_later`.
class DataClassSerializer < ActiveJob::Serializers::ObjectSerializer
  def serialize?(argument)
    argument.is_a?(DataClass::Serializable)
  end

  def serialize(object)
    super('class' => object.class.name, 'attributes' => object.serialized_attributes)
  end

  def deserialize(hash)
    klass = hash['class'].constantize
    unless klass.include?(DataClass::Serializable)
      raise ArgumentError, "#{klass} does not include DataClass::Serializable"
    end

    klass.from_serialized_attributes(hash['attributes'])
  end
end
