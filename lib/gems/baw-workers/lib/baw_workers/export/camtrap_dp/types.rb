# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      module Types
        include ::BawWorkers::Dry::Types

        UtcTimeSeconds = Constructor(Timestamp) { |input|
          next nil if input.blank?

          Timestamp.new(UtcTime[input], 0)
        }

        UtcTimeMicroseconds = Constructor(Timestamp) { |input|
          next nil if input.blank?

          Timestamp.new(UtcTime[input], 6)
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

        UrlOrPath = Url | SafePath
        Schema = Types::Hash | UrlOrPath

        Role = Types::String.default('contributor').enum(
          'contact',
          'principalInvestigator',
          'rightsHolder',
          'publisher',
          'contributor'
        )

        SamplingDesign = Types::String.default('simpleRandom').enum(
          'simpleRandom',
          'systematicRandom',
          'clusteredRandom',
          'experimental',
          'targeted',
          'opportunistic'
        )

        CaptureMethod = Types::String.enum(
          'activityDetection',
          'continuous',
          'recordingSchedule'
        )

        TaxonRank = Types::String.enum(
          'kingdom', 'phylum', 'class', 'order',
          'family', 'genus', 'species', 'subspecies'
        )

        GeoJSON = Types::Hash
      end
    end
  end
end
