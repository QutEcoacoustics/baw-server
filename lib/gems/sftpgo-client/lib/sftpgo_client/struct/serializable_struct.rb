# frozen_string_literal: true

module SftpgoClient
  class SerializableStruct < Dry::Struct
    # Allows a struct to be serialized into JSON by first converting it to a hash
    def to_json(*a)
      to_h.to_json(*a)
    end
  end
end

if Dry::Struct.method_defined?(:to_json) && Dry::Struct.method(:to_json).owner.name != 'ActiveSupport::ToJsonWithActiveSupportEncoder'
  raise 'SftpgoClient::SerializableStruct sub-class patch no longer needed'
end
