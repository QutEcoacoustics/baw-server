# frozen_string_literal: true

module BawWorkers
  module Dry
    # custom dry-types
    # https://dry-rb.org/gems/dry-types/master/getting-started/
    module Types
      # @!parse
      #   include Dry::Types
      include ::Dry.Types

      StrictSymbolizingHash = Types::Hash.schema({}).strict.with_key_transform(&:to_sym)

      Statuses = String.enum(
        BawWorkers::ActiveJob::Status::STATUS_QUEUED,
        BawWorkers::ActiveJob::Status::STATUS_WORKING,
        BawWorkers::ActiveJob::Status::STATUS_COMPLETED,
        BawWorkers::ActiveJob::Status::STATUS_FAILED,
        BawWorkers::ActiveJob::Status::STATUS_ERRORED,
        BawWorkers::ActiveJob::Status::STATUS_KILLED
      )

      # MediaJobTypes = Types::Coercible::Symbol.enum(
      #   :audio,
      #   :spectrogram
      # )

      SampleRate = Types::Strict::Integer.constrained(gt: 0)

      Window = Types::Strict::Integer.constrained(
        included_in: [128, 256, 512, 1024, 2048, 4096]
      )

      Channel = Types::Strict::Integer.constrained(
        gteq: 0,
        lt: 16
      )
    end
  end
end
