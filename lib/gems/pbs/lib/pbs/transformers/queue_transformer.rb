# frozen_string_literal: true

module PBS
  module Transformers
    class QueueTransformer < ::Dry::Transformer::Pipe
      import Functions

      NOT_NIL = lambda { |value|
        !value.nil?
      }.freeze

      # downcase and symbolize most keys
      define! do
        # JSON string containing a job list
        # (might already be a Hash so optionally skip this step)
        is String do
          parse_json
        end
        # queue list wrapper
        map_keys(&:normalize_key)

        # hash of queues
        map_value(:queue) do
          # for each queue entry
          map_hash_values do
            map_keys(&:normalize_key)

            [
              :resources_max,
              :resources_min,
              :resources_assigned,
              :max_run_res
            ].each do |key|
              map_value(key) do
                guard(NOT_NIL) do
                  map_keys(&:normalize_key)
                end
              end
            end
          end
        end

        constructor_inject(::PBS::Models::QueueList)
      end
    end
  end
end
