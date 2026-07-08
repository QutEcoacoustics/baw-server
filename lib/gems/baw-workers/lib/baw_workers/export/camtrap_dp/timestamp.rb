# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      Timestamp = Data.define(:time, :precision) {
        def to_s
          time.iso8601(precision)
        end
      }
    end
  end
end
