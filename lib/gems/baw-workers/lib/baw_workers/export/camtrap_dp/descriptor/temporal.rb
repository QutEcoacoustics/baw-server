# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/temporal
        class Temporal < Descriptor
          attribute :start, Types::UtcTimeSeconds
          attribute :end, Types::UtcTimeSeconds
        end
      end
    end
  end
end
