# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    module Status
      # A struct containing the status object
      class StatusData < ::BawWorkers::Dry::StrictStruct
        # @!attribute [r] job_id
        #   @return [String]
        attribute :job_id, StatusTypes::String
        # @!attribute [r] name
        #   @return [String]
        attribute :name, StatusTypes::String.optional
        # @!attribute [r] status
        #   @return [String]
        attribute :status, StatusTypes::Statuses
        # @!attribute [r] messages
        #   @return [Array<String>]
        attribute :messages, StatusTypes::Array.of(StatusTypes::String).default([].freeze)
        # @!attribute [r] time
        #   @return [DateTime]
        attribute :time, (StatusTypes::JSON::Time.default { Time.now })
        # @!attribute [r] options
        #   @return [String]
        attribute :options, StatusTypes::Hash

        # @!attribute [r] progress
        #   @return [BigDecimal]
        attribute :progress, StatusTypes::JSON::Decimal
        # @!attribute [r] total
        #   @return [BigDecimal]
        attribute :total, StatusTypes::JSON::Decimal

        def queued?
          status == STATUS_QUEUED
        end

        def working?
          status == STATUS_WORKING
        end

        def completed?
          status == STATUS_COMPLETED
        end

        def failed?
          status == STATUS_FAILED
        end

        def errored?
          status == STATUS_ERRORED
        end

        def killed?
          status == STATUS_KILLED
        end

        def terminal?
          TERMINAL_STATUSES.include?(status)
        end

        def killable?
          !terminal?
        end

        def percent_complete
          if completed?
            100
          elsif queued?
            0
          else
            t = total.zero? || total.nil? ? 1 : total
            (((progress || 0).to_d / t) * 100).to_i
          end
        end
      end
    end
  end
end
