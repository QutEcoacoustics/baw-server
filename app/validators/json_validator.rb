# frozen_string_literal: true

# https://gist.github.com/joost/7ee5fbcc40e377369351

# Put this code in lib/validators/json_validator.rb
# Usage in your model:
#   validates :json_attribute, presence: true, json: true
#
# To have a detailed error use something like:
#   validates :json_attribute, presence: true, json: {message: :some_i18n_key}
# In your yaml use:
#   some_i18n_key: "detailed exception message: %{exception_message}"
class JsonValidator < ActiveModel::EachValidator
  def initialize(options)
    options.reverse_merge!(message: :invalid)
    super(options)
  end

  def validate_each(record, attribute, value)
    # bypass rail's eager serialization of values
    if value.is_a?(Hash)
      return true if record.attributes_before_type_cast[attribute.to_s].is_a?(Hash)

      value = record.attributes_before_type_cast[attribute.to_s]
    end

    value = value.strip if value.is_a?(String)

    ActiveSupport::JSON.decode(value)
  rescue MultiJson::LoadError, TypeError => e
    record.errors.add(attribute, options[:message], exception_message: e.message)
  end
end
