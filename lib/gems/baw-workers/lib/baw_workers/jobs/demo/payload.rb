# frozen_string_literal: true

module BawWorkers
  module Jobs
    module Demo
      # a class showing our recommended payload structure
      class Payload < ::BawWorkers::Dry::SerializedStrictStruct
        # @!attribute [r] parameter
        #   @return [String]
        attribute :parameter, ::BawWorkers::Dry::Types::String
      end
    end
  end
end
