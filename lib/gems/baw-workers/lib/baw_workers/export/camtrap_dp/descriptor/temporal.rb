# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        class Temporal < Descriptor
          attribute :start, Types::String
          attribute :end, Types::String
        end
      end
    end
  end
end
