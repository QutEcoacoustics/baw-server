# frozen_string_literal: true

module BawWorkers
  module Dry
    # custom dry-types
    # https://dry-rb.org/gems/dry-types/master/getting-started/
    module Types
      # @!parse
      #   include Dry::Types
      include ::Dry.Types
      include ::BawApp::Types

      ID = Strict::Integer.constrained(gteq: 0)
      NATURAL = Strict::Integer.constrained(gteq: 0)

      DirectoryString = Strict::String.constructor { |item|
        item.ends_with?('/') ? item : "#{item}/"
      }
      TrimmedDirectoryString = Strict::String.constructor { |item|
        next item if item.nil?

        item = item.ends_with?('/') ? item.slice(..-2) : item.to_s
        item.start_with?('/') ? item.slice(1..) : item
      }

      UtcOffsetString = Strict::String.constrained(format: BawWorkers::FileInfo::UTC_OFFSET_REGEX)

      StrictSymbolizingHash = Types::Hash.schema({}).strict.with_key_transform(&:to_sym)

      # MediaJobTypes = Types::Coercible::Symbol.enum(
      #   :audio,
      #   :spectrogram
      # )

      SampleRate = Types::Coercible::Integer.constrained(gt: 0)

      Window = Types::Coercible::Integer.constrained(
        included_in: [128, 256, 512, 1024, 2048, 4096]
      )

      Channel = Types::Coercible::Integer.constrained(
        gteq: 0,
        lt: 16
      )

      DeeplySymbolizedHash = Types::Hash.constructor { |item|
        raise ArgumentError, 'value must be a Hash' unless item.is_a?(::Hash)

        item.deep_symbolize_keys
      }

      UnixTime = Constructor(::Time) { |value|
        next nil if value.blank?

        ::Time.zone.at(value)
      }
    end
  end
end
