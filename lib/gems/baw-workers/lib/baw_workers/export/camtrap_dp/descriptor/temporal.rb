# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      module Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/temporal
        class Temporal < Base
          attribute :start, Types::UtcTimeSeconds
          attribute :end, Types::UtcTimeSeconds
        end
      end
    end
  end
end
