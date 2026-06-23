module BawWorkers
  module Export
    module CamtrapDp
      module Table
        class Observation < ::Dry::Struct
          Types = BawWorkers::Dry::Types
          OBSERVATION_LEVEL = 'interval'
          OBSERVATION_TYPE = 'animal'

          # Unique identifier of the observation.
          attribute :observationID, Types::Coercible::String
          # Coercible because the schema requires strings for IDs
          # Identifier of the deployment the observation belongs to. Foreign key to `deployments.deploymentID`.
          attribute :deploymentID, Types::Coercible::String
          # Identifier of the media file that was classified. Only applicable for media-based observations (`observationLevel` = `media`). Foreign key to `media.mediaID`.
          attribute? :mediaID, Types::Coercible::String.optional
          # Identifier of the event the observation belongs to. Facilitates linking event-based and media-based observations with a permanent identifier.
          attribute? :eventID, Types::String.optional
          # Date and time at which the event started. Formatted as an ISO 8601 string with timezone designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
          attribute :eventStart, Types::UtcTimeMicros
          # Date and time at which the event ended. Formatted as an ISO 8601 string with timezone designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
          attribute :eventEnd, Types::UtcTimeMicros
          # Level at which the observation was classified. `media` for media-based observations that are directly associated with a media file (`mediaID`). These are especially useful for machine learning and don't need to be mutually exclusive (e.g. multiple classifications are allowed). `event` for event-based observations that consider an event (comprising a collection of media files). These are especially useful for ecological research and should be mutually exclusive, so that their `count` can be summed. Acoustic extension adds 'interval' to accepted enum values but seemingly only to the field on observations table, not the package level observationLevel field
          # TODO comment on repo. - that the enum doesn't match?
          # TODO we are always interval
          attribute :observationLevel, Types::String.enum('media', 'event', 'interval')
          # Type of the observation. All categories in this vocabulary have to be understandable from an AI point of view. `unknown` describes classifications with a `classificationProbability` below some predefined threshold i.e. neither humans nor AI can say what was recorded.
          # TODO: Required but uncertain how we would handle on a per-row basis. Defaulting to 'animal' for ALA species exports
          # TODO common or species name = animal, sounds like or looks like tag types shouldnt be emitted, general tags => ?
          # Contains ( string match ) =>
          #   motor, car, truck, boats => vehicle
          #   human, voice, speech => human
          # We have an unknown tag => unknown
          # else unclassified if can't match any of those rules
          attribute :observationType, Types::String.enum('animal', 'human', 'vehicle', 'blank', 'unknown', 'unclassified') # nolint
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
          # Method (most recently) used to classify the observation. Mapped from provenance_id presence: machine if provenance present, human otherwise.
          attribute? :classificationMethod, Types::String.enum('human', 'machine').optional
          # Name or identifier of the person or AI algorithm that (most recently) classified the observation.
          attribute? :classifiedBy, Types::String.optional
          # Date and time of the (most recent) classification. Formatted as an ISO 8601 string with timezone designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
          attribute? :classificationTimestamp, Types::UtcTimeSeconds.optional
          # Degree of certainty of the (most recent) classification. Expressed as a probability, with `1` being maximum certainty. Omit or provide an approximate probability for human classifications.
          # ! We could use score here but it isn't scaled 0-1. And there is no place for verification consensus currently.
          # TODO we will instead emit our own score field
          attribute? :classificationProbability, Types::Coercible::Float.optional
          # A confirmation that the classified species was observed via other means. Not related to our idea of confirmations. https://github.com/tdwg/camtrap-dp/issues/453
          attribute? :classificationConfirmation, Types::String.enum('captured', 'heardOnSite', 'seenOnSite').optional
          # Tag(s) associated with the observation. Formatted as a pipe (`|`) separated list for multiple values, with values optionally formatted as `key:value` pairs.
          attribute? :observationTags, Types::String.optional
          # Comments or notes about the observation.
          attribute? :observationComments, Types::String.optional
          # This is the mapping of our data onto the schema - how to get the values for those fields

          def self.mapping(tagging)
            ae = tagging.audio_event
            ar = ae.audio_recording

            Observation.new(
              observationID: tagging.id,
              mediaID: ar.id,
              deploymentID: ar.site_id,
              eventStart: ar.recorded_date + ae.start_time_seconds.seconds,
              eventEnd: ar.recorded_date + ae.end_time_seconds.seconds,
              observationLevel: OBSERVATION_LEVEL,
              observationType: OBSERVATION_TYPE,
              eventID: nil, # Since we are emitting 'media' level observations, we leave this blank. Their event concept is different to ours.
              frequencyHigh: ae.high_frequency_hertz,
              frequencyLow: ae.low_frequency_hertz,
              classificationTimestamp: tagging.created_at,
              classificationMethod: ae.provenance_id ? 'machine' : 'human', # TODO: May not be future proof?
              classifiedBy: ae.provenance&.name || tagging.creator.user_name,
              scientificName: tagging.tag.text
            )
          end
        end
      end
    end
  end
end
