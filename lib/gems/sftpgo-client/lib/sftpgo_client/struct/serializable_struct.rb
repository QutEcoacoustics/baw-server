# frozen_string_literal: true

module SftpgoClient
  # Allows a struct to be serialized into JSON by first converting it to a hash
  class SerializableStruct < Dry::Struct
    # https://dry-rb.org/gems/dry-struct/1.0/recipes/
    # allow transforming keys to symbols
    transform_keys(&:to_sym)

    def to_json(...)
      to_h.to_json(...)
    end
  end
end

if Dry::Struct.method_defined?(:to_json) && Dry::Struct.method(:to_json).owner.name != 'ActiveSupport::ToJsonWithActiveSupportEncoder'
  raise 'SftpgoClient::SerializableStruct sub-class patch no longer needed'
end
