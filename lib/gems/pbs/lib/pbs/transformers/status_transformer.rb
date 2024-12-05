# frozen_string_literal: true

module PBS
  module Transformers
    # transforms a PBS json payload into a normalized job list
    class StatusTransformer < ::Dry::Transformer::Pipe
      import Functions

      NOT_NIL = lambda { |value|
        !value.nil?
      }.freeze

      # downcase and symbolize most keys
      # - json payload has inconsistent capitalization
      # - ignoring any string maps where the keys are not field names
      define! do
        # JSON string containing a job list
        # (might already be a Hash so optionally skip this step)
        is String do
          parse_json
        end
        # job list
        map_keys(&:normalize_key)

        # map of job entries keyed by job id
        # id of job should remain a string
        map_value(:jobs) do
          # for each job entry
          map_hash_values do
            map_keys(&:normalize_key)

            # decompose depend object
            map_value(:depend) do
              parse_depend
            end

            map_value(:resources_used) do
              guard(NOT_NIL) do
                map_keys(&:normalize_key)
              end
            end

            map_value(:resource_list) do
              guard(NOT_NIL) do
                map_keys(&:normalize_key)
              end
            end

            map_value(:estimated) do
              guard(NOT_NIL) do
                map_keys(&:normalize_key)
              end
            end
          end

          # insert the job id into each job entry
          map_values_with_key do
            embed_key_into_value(:job_id)
          end
        end

        constructor_inject(::PBS::Models::JobList)
      end
    end
  end
end
