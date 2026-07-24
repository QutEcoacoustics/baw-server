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

      # Used in the Camtrap Data Package export for timestamps serialized with whole-second precision.
      #
      # @return [BawWorkers::Export::CamtrapDp::Timestamp] wrapper that preserves the offset on Time inputs and formats via `iso8601(0)`.
      UtcTimeSeconds = Constructor(BawWorkers::Export::CamtrapDp::Timestamp) { |input|
        next nil if input.blank?

        BawWorkers::Export::CamtrapDp::Timestamp.new(UtcTime[input], 0)
      }

      # Used in the Camtrap Data Package export for timestamps serialized with microsecond precision.
      #
      # @return [BawWorkers::Export::CamtrapDp::Timestamp] wrapper that preserves the offset on Time inputs and formats via `iso8601(6)`.
      UtcTimeMicroseconds = Constructor(BawWorkers::Export::CamtrapDp::Timestamp) { |input|
        next nil if input.blank?

        BawWorkers::Export::CamtrapDp::Timestamp.new(UtcTime[input], 6)
      }

      Url = Types::String.constructor { |input|
        URI.parse(input)
        input.to_s
      }

      SafePath = Types::String.constructor { |input|
        path = ::Pathname.new(input)
        first_path_component = path.to_s.split('/').first

        raise ArgumentError, 'value must be a safe relative path' if path.absolute?
        raise ArgumentError, 'value must be a safe relative path' unless /\A\.+\z/.match(first_path_component).nil?

        input
      }

      # `url-or-path` is a frictionless type for a string that must either be a fully qualified URL or a relative POSIX path.
      # https://specs.frictionlessdata.io/data-resource/#data-location
      UrlOrPath = Url | SafePath

      Schema = Types::Hash | UrlOrPath

      # package.contributors[].role
      Role = Types::String.default('contributor').enum(
        'contact',
        'principalInvestigator',
        'rightsHolder',
        'publisher',
        'contributor'
      )

      # package.project.samplingDesign
      # Allow user input but fall back to simpleRandom. Eventually this would be useful Project level metadata to have
      # TODO could make a proposal to the format to allow an unknown value here
      SamplingDesign = Types::String.default('simpleRandom').enum(
        'simpleRandom',
        'systematicRandom',
        'clusteredRandom',
        'experimental',
        'targeted',
        'opportunistic'
      )

      # in package.project.captureMethod; media.captureMethod
      # EMU can extract this from recording files (we discard it atm). Until then have to ask.
      CaptureMethod = Types::String.enum(
        'activityDetection',
        'continuous',
        'recordingSchedule'
      )

      # package.taxonnomic[].taxonRank
      TaxonRank = Types::String.enum(
        'kingdom', 'phylum', 'class', 'order',
        'family', 'genus', 'species', 'subspecies'
      )

      # Used for documentation value. The profile includes GeoJSON schema validation.
      GeoJSON = Types::Hash
    end
  end
end
