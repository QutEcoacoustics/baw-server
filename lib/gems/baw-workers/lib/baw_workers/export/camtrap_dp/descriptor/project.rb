# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        class Project < Descriptor
          attribute :title, Types::String
          attribute :samplingDesign, Types::SamplingDesign
          attribute :captureMethod, Types::Array.of(Types::CaptureMethod)
          attribute :individualAnimals, Types::Bool # TODO: just false for now + comment explaining we don't support atm until add platform feature or request

          # Confusingly 'interval' is allowed for the observation table field but not for the package metadata field
          attribute :observationLevel, Types::Array.of(Types::String.default('media').enum('media', 'event')) # TODO: just default to media, we don't distinguish. In future might be able to merge things to reduce duplication
          attribute? :id, Types::String.optional
          attribute? :acronym, Types::String.optional
          attribute? :description, Types::String.optional
          attribute? :path, Types::String.optional
          attribute? :protocolType, Types::String.default('acoustic').enum('camera-trapping', 'acoustic')
          attribute? :classificationEffort, Types::String.optional
        end
      end
    end
  end
end
