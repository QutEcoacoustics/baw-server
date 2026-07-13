# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        class Temporal < Descriptor
          attribute :start, Types::UtcTimeSeconds
          attribute :end, Types::UtcTimeSeconds
        end
      end
    end
  end
end
