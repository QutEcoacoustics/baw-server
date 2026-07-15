module BawWorkers
  module Export
    module CamtrapDp
      module Table
        # Represents a row in the `observations` table of the Camtrap Data Package.
        #
        # Attributes are defined in schema order (required for CSV validation).
        class Observation < BawWorkers::Dry::OrderedStruct
          Types = BawWorkers::Dry::Types

          # Our concept of an event maps to the interval type of observation. See explanation on #observationLevel
          OBSERVATION_LEVEL = 'interval'

          # Unique identifier of the observation.
          attribute :observationID, Types::Coercible::String

          # Identifier of the deployment the observation belongs to. Foreign key to `deployments.deploymentID`.
          attribute :deploymentID, Types::Coercible::String

          # Identifier of the media file that was classified. Only applicable for media-based observations (`observationLevel` = `media`). Foreign key to `media.mediaID`.
          attribute? :mediaID, Types::Coercible::String.optional

          # Identifier of the event the observation belongs to. Facilitates linking event-based and media-based observations with a permanent identifier.
          attribute? :eventID, Types::String.optional

          # Date and time at which the event started. Formatted as an ISO 8601 string with timezone designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
          attribute :eventStart, Types::UtcTimeMicroseconds

          # Date and time at which the event ended. Formatted as an ISO 8601 string with timezone designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
          attribute :eventEnd, Types::UtcTimeMicroseconds

          # Level at which the observation was classified. `media` for media-based observations that are directly associated with a media file (`mediaID`). These are especially useful for machine learning and don't need to be mutually exclusive (e.g. multiple classifications are allowed). `event` for event-based observations that consider an event (comprising a collection of media files). These are especially useful for ecological research and should be mutually exclusive, so that their `count` can be summed. Acoustic extension adds 'interval' to accepted enum values but seemingly only to the field on observations table, not the package level observationLevel field
          attribute :observationLevel, Types::String.enum('media', 'event', 'interval')

          # Type of the observation. All categories in this vocabulary have to be understandable from an AI point of view. `unknown` describes classifications with a `classificationProbability` below some predefined threshold i.e. neither humans nor AI can say what was recorded.
          attribute :observationType,
            Types::String.enum('animal', 'human', 'vehicle', 'blank', 'unknown', 'unclassified')

          # Type of the device setup action (if any) associated with the observation.
          attribute? :deviceSetupType, Types::String.enum('setup', 'calibration').optional

          # Scientific name of the observed individual(s).
          attribute? :scientificName, Types::String.optional

          # Number of observed individuals (optionally of given life stage, sex and behavior).
          attribute? :count, Types::Integer.optional

          # Age class or life stage of the observed individual(s).
          attribute? :lifeStage, Types::String.enum('adult', 'subadult', 'juvenile').optional

          # Sex of the observed individual(s)
          attribute? :sex, Types::String.enum('female', 'male').optional

          # Dominant behavior of the observed individual(s), preferably expressed as controlled values (e.g. grazing, browsing, rooting, vigilance, running, walking). Formatted as a pipe (`|`) separated list for multiple values, with the dominant behavior listed first.
          attribute? :behavior, Types::String.optional

          # Identifier of the observed individual.
          attribute? :individualID, Types::String.optional

          # Distance from the device to the observed individual identified by `individualID`. Expressed in meters. Required for distance analyses (e.g. [Howe et al. 2017](https://doi.org/10.1111/2041-210X.12790)) and random encounter modelling (e.g. [Rowcliffe et al. 2011](https://doi.org/10.1111/j.2041-210X.2011.00094.x)).
          attribute? :individualPositionRadius, Types::Coercible::Float.optional

          # Angular distance from the device view centerline to the observed individual identified by `individualID`. Expressed in degrees, with negative values left, `0` straight ahead and positive values right. Required for distance analyses (e.g. [Howe et al. 2017](https://doi.org/10.1111/2041-210X.12790)) and random encounter modelling (e.g. [Rowcliffe et al. 2011](https://doi.org/10.1111/j.2041-210X.2011.00094.x)).
          attribute? :individualPositionAngle, Types::Coercible::Float.optional

          # Average movement speed of the observed individual identified by `individualID`. Expressed in meters per second. Required for random encounter modelling (e.g. [Rowcliffe et al. 2016](https://doi.org/10.1002/rse2.17)).
          attribute? :individualSpeed, Types::Coercible::Float.optional

          # Horizontal position of the top-left corner of a bounding box that encompasses the observed individual(s) in the media file identified by `mediaID`. Or the horizontal position of an object in that media file. Measured from the left and relative to media file width.
          attribute? :bboxX, Types::Coercible::Float.optional

          # Vertical position of the top-left corner of a bounding box that encompasses the observed individual(s) in the media file identified by `mediaID`. Or the vertical position of an object in that media file. Measured from the top and relative to the media file height.
          attribute? :bboxY, Types::Coercible::Float.optional

          # Width of a bounding box that encompasses the observed individual(s) in the media file identified by `mediaID`. Measured from the left of the bounding box and relative to the media file width.
          attribute? :bboxWidth, Types::Coercible::Float.optional

          # Height of the bounding box that encompasses the observed individual(s) in the media file identified by `mediaID`. Measured from the top of the bounding box and relative to the media file height.
          attribute? :bboxHeight, Types::Coercible::Float.optional

          # Lower limit of the frequency range over which the observation applies. Expressed in Hertz. Must be lower than frequencyHigh.
          attribute? :frequencyLow, Types::Coercible::Float.optional

          # Higher limit of the frequency range over which the observation applies. Expressed in Hertz. Must be higher than frequencyHigh.
          attribute? :frequencyHigh, Types::Coercible::Float.optional

          # Method (most recently) used to classify the observation.
          attribute? :classificationMethod, Types::String.enum('human', 'machine').optional

          # Name or identifier of the person or AI algorithm that (most recently) classified the observation.
          attribute? :classifiedBy, Types::String.optional

          # Date and time of the (most recent) classification. Formatted as an ISO 8601 string with timezone designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
          attribute? :classificationTimestamp, Types::UtcTimeSeconds.optional

          # Degree of certainty of the (most recent) classification. Expressed as a probability, with `1` being maximum certainty. Omit or provide an approximate probability for human classifications.
          attribute? :classificationProbability, Types::Coercible::Float.optional

          # A confirmation that the classified species was observed via other means. Not related to our idea of confirmations. https://github.com/tdwg/camtrap-dp/issues/453
          attribute? :classificationConfirmation, Types::String.enum('captured', 'heardOnSite', 'seenOnSite').optional

          # Tag(s) associated with the observation. Formatted as a pipe (`|`) separated list for multiple values, with values optionally formatted as `key:value` pairs.
          attribute? :observationTags, Types::String.optional

          # Comments or notes about the observation.
          attribute? :observationComments, Types::String.optional

          def self.anchored_union(*patterns)
            /\A#{Regexp.union(patterns)}\z/
          end

          TYPE_OF_ANIMAL = [
            'species_name',
            'common_name'
          ]
          GENERAL_TEXT_UNKNOWN = anchored_union(
            /unknown/i,
            /unknown_\d+/i,
            /unsure/i
          )
          GENERAL_TEXT_HUMAN = anchored_union(
            /baby/i,
            /human voice/i
          )
          GENERAL_TEXT_VEHICLE = anchored_union(
            /airplane/i,
            /boat/i,
            /car/i,
            /chainsaw/i,
            /engine/i,
            /helicopter/i,
            /motor/i,
            /train/i,
            /train passing/i,
            /train horn/i,
            /machine generated/i,
            /vehicle/i
          )

          # Temporary solution; remove after https://github.com/QutEcoacoustics/baw-server/issues/1009.
          def self.observation_type(tag)
            case [tag.type_of_tag, tag.text]
            in [type, _] if TYPE_OF_ANIMAL.include?(type)
              'animal'
            in ['general', GENERAL_TEXT_UNKNOWN]
              'unknown'
            in ['general', GENERAL_TEXT_HUMAN]
              'human'
            in ['general', GENERAL_TEXT_VEHICLE]
              'vehicle'
            else
              'unclassified'
            end
          end

          # Fields not covered by the standard that we would like to include in the export:
          #
          # audio_event.score - The score is unbounded and not a probability, so it cannot be used for classificationProbability.
          # verifications - e.g. verification_correct count, ratio of correct to total verifications etc.#
          #
          # See Camtrap DP FAQ for ways to include additional fields https://camtrap-dp.tdwg.org/faq/#measurements;
          # either as key:value pairs in the observationTags field, or as a custom table with a schema.  Also see the
          # community feedback issue from the bioacoustic extension report https://github.com/tdwg/camtrap-dp/issues/457
          #
          # @param tagging [Tagging] the tagging to map
          # @param deployment [DeploymentAccumulator::Deployment] the deployment metadata for the tagging; its
          #   `ensure_timezone` method applies the forced UTC offset, site timezone, or UTC fallback.
          # @return [Observation] the observation struct with the mapped values
          def self.mapping(tagging, deployment)
            ae = tagging.audio_event
            ar = ae.audio_recording

            # ? Is this future proof?
            classification_method = ae.provenance_id ? 'machine' : nil

            # ? When audio_event.provenance is null, `tagging.creator` queries the user table:
            # - Should we eager load the user association to avoid this?
            # - The user_name is not a real name, is that an issue for the package or for ALA?
            classified_by = ae.provenance&.name || tagging.creator.user_name

            scientific_name = tagging.tag.type_of_tag == 'species_name' ? tagging.tag.text : nil

            observation_type = observation_type(tagging.tag)

            Observation.new(
              observationID: tagging.id,
              deploymentID: ar.site_id,
              mediaID: ar.id,
              eventID: nil,
              eventStart: deployment.ensure_timezone(ar.recorded_date + ae.start_time_seconds.seconds),
              eventEnd: deployment.ensure_timezone(ar.recorded_date + ae.end_time_seconds.seconds),
              observationLevel: OBSERVATION_LEVEL,
              observationType: observation_type,
              deviceSetupType: nil,
              scientificName: scientific_name,
              count: nil,
              lifeStage: nil,
              sex: nil,
              behavior: nil,
              individualID: nil,
              individualPositionRadius: nil,
              individualPositionAngle: nil,
              individualSpeed: nil,
              bboxX: nil,
              bboxY: nil,
              bboxWidth: nil,
              bboxHeight: nil,
              frequencyLow: ae.low_frequency_hertz,
              frequencyHigh: ae.high_frequency_hertz,
              classificationMethod: classification_method,
              classifiedBy: classified_by,
              classificationTimestamp: deployment.ensure_timezone(tagging.created_at),
              classificationProbability: nil,
              classificationConfirmation: nil,
              observationTags: nil,
              observationComments: nil
            )
          end
        end
      end
    end
  end
end
