# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/project
        class Project < Descriptor
          attribute :title, Types::String
          attribute :samplingDesign, Types::SamplingDesign
          attribute :captureMethod, Types::Array.of(Types::CaptureMethod)
          attribute :individualAnimals, Types::Bool.default(false)
          attribute :observationLevel, Types::Array.of(Types::String.default('media').enum('media', 'event'))
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
