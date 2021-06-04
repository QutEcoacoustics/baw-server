# frozen_string_literal: true

module BawWorkers
  module ActiveJob
    module Status
      # A struct containing the status object
      class StatusData < BawWorkers::Dry::StrictStruct
        # @!attribute job_id
        #   @return [String]
        attribute :job_id, Types::String
        # @!attribute name
        #   @return [String]
        attribute :name, Types::String
        # @!attribute status
        #   @return [String]
        attribute :status, STATUSES
        # @!attribute messages
        #   @return [Array<String>]
        attribute :messages,  Types::Array.of(Types::Coercible::String)
        # @!attribute time
        #   @return [DateTime]
        attribute :time, (Types::DateTime.default { Time.now.to_i })
        # @!attribute options
        #   @return [String]
        attribute :options, Types::Hash
        # @!attribute progress
        #   @return [BigDecimal]
        attribute :progress, Types::Coercible::Decimal
        # @!attribute total
        #   @return [BigDecimal]
        attribute :total, Types::Coercible::Decimal

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

        def killed?
          status == STATUS_KILLED
        end

        def terminal?
          completed? || killed? || failed?
        end

        def killable?
          !failed? && !completed? && !killed?
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
