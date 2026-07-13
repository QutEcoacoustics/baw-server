# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      Timestamp = Data.define(:time, :precision) {
        def to_s
          time.iso8601(precision)
        end

        # Serialize to a string when as_json is called during our local package validation
        alias_method :as_json, :to_s
      }
    end
  end
end
