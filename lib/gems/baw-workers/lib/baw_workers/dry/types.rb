# frozen_string_literal: true

module BawWorkers
  module Dry
    # custom dry-types
    # https://dry-rb.org/gems/dry-types/master/getting-started/
    module Types
      ::Dry::Struct.prepend(BawWorkers::Dry::Struct)

      TimeWithPrecision = Class.new do
        def initialize(time, precision:)
          @time = time
          @precision = precision
        end

        def to_s
          @time.utc.iso8601(@precision)
        end
      end

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

      UtcTimeMicros = Constructor(TimeWithPrecision) { |input|
        next nil if input.blank?

        TimeWithPrecision.new(UtcTime[input], precision: 6)
      }

      UtcTimeSeconds = Constructor(TimeWithPrecision) { |input|
        next nil if input.blank?

        TimeWithPrecision.new(UtcTime[input], precision: 0)
      }

      # Camtrap DataPackage related types --

      #  `url-or-path` is a frictionless type for a string that must either be a fully qualified URL or a relative POSIX path.
      URLOrPath = Types::String

      Schema = URLOrPath | Types::Hash
      # package.contributors[].role
      Role = Types::String.default('contributor').enum(
        'contact',
        'principalInvestigator',
        'rightsHolder',
        'publisher',
        'contributor'
      )

      # package.project.samplingDesign
      # ! Do we want to default this? Or always require user input
      # TODO lets allow input but fall back to simpleRandom for now. Eventually this would be useful Project level metadata to have
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
      # TODO emu can extract this from recording files (we discard it atm)
      # TODO until then have to ask
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

      # package.spatial
      GeoJSON = Types::Hash
    end
  end
end
