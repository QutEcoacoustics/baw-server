# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      module Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/project
        class Project < Base
          attribute :title, Types::String
          attribute :samplingDesign, Types::SamplingDesign
          attribute :captureMethod, Types::Array.of(Types::CaptureMethod)
          attribute :individualAnimals, Types::Bool.default(false)
          attribute :observationLevel, Types::Array.of(Types::String.default('media').enum('media', 'event'))
          attribute? :id, Types::String
          attribute? :acronym, Types::String
          attribute? :description, Types::String
          attribute? :path, Types::String
          attribute? :protocolType, Types::String.default('acoustic').enum('camera-trapping', 'acoustic')
          attribute? :classificationEffort, Types::String
        end
      end
    end
  end
end
