module BawWorkers
  module Export
    module CamtrapDp
      module Table
        # Represents a row in the `deployment` table of the Camtrap Data Package.
        #
        # Attributes are defined in schema order (required for CSV validation).
        class Deployment < BawWorkers::Dry::OrderedStruct
          Types = BawWorkers::Dry::Types

          # Unique identifier of the deployment.
          attribute :deploymentID, Types::Coercible::String

          # Identifier of the deployment location.
          attribute? :locationID, Types::Coercible::String

          # Name given to the deployment location.
          attribute? :locationName, Types::String

          # Latitude of the deployment location in decimal degrees, using the WGS84 datum.
          attribute :latitude, Types::Nominal::Decimal

          # Longitude of the deployment location in decimal degrees, using the WGS84 datum.
          attribute :longitude, Types::Nominal::Decimal

          # Horizontal distance from the given `latitude` and `longitude` describing the smallest circle containing the deployment location. Expressed in meters. Especially relevant when coordinates are rounded to protect sensitive species.
          attribute? :coordinateUncertainty, Types::Coercible::Integer.constrained(gteq: 1)

          # Elevation (altitude, usually above sea level) in meters
          attribute? :elevation, Types::Integer

          # Date and time at which the deployment was started. Formatted as an ISO 8601 string with timezone designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
          attribute :deploymentStart, Types::UtcTimeSeconds

          # Date and time at which the deployment was ended. Formatted as an ISO 8601 string with timezone designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
          attribute :deploymentEnd, Types::UtcTimeSeconds

          # Name or identifier of the person or organization that deployed the device.
          attribute? :setupBy, Types::String

          # Identifier of the device used for the deployment (e.g. the device device serial number).
          attribute? :deviceID, Types::String

          # Manufacturer and model of the device. Formatted as `manufacturer-model`.
          attribute? :deviceModel, Types::String

          # The substrate to which the device is mounted.
          attribute? :devicePlatform,
            Types::String.enum('buoy', 'vegetation', 'building', 'structure', 'pole', 'unattached')

          # Predefined duration after detection when further activity is ignored. Expressed in seconds.
          attribute? :deviceDelay, Types::Integer

          # Height at which the device was deployed. Expressed in meters. Not to be combined with `deviceDepth`.
          attribute? :deviceHeight, Types::Coercible::Float

          # Depth at which the device was deployed. Expressed in meters. Not to be combined with `deviceHeight`.
          attribute? :deviceDepth, Types::Coercible::Float

          # Angle at which the device was deployed in the vertical plane. Expressed in degrees, with `-90` facing down, `0` horizontal and `90` facing up.
          attribute? :deviceTilt, Types::Integer

          # Angle at which the device was deployed in the horizontal plane. Expressed in decimal degrees clockwise from north, with values ranging from `0` to `360`: `0` = north, `90` = east, `180` = south, `270` = west.
          attribute? :deviceHeading, Types::Integer

          # Description of the recording schedule.
          attribute? :recordingSchedule, Types::String

          # Maximum distance at which the device can reliably detect activity. Expressed in meters. Typically measured by having a human move in front of the device.
          attribute? :detectionDistance, Types::Coercible::Float

          # `true` if bait was used for the deployment. More information can be provided in `tags` or `comments`.
          attribute? :baitUse, Types::Bool

          # Type of the feature (if any) associated with the deployment.
          attribute? :locationType,
            Types::String.enum('roadPaved', 'roadDirt', 'trailHiking', 'trailGame', 'roadUnderpass', 'roadOverpass', 'roadBridge',
              'culvert', 'burrow', 'nestSite', 'carcass', 'waterSource', 'fruitingTree')

          # Short characterization of the habitat at the deployment location.
          attribute? :habitat, Types::String

          # Deployment group(s) associated with the deployment. Deployment groups can have a spatial (arrays, grids, clusters), temporal (sessions, seasons, months, years) or other context. Formatted as a pipe (`|`) separated list for multiple values, with values preferably formatted as `key:value` pairs.
          attribute? :deploymentGroups, Types::String

          # Tag(s) associated with the deployment. Formatted as a pipe (`|`) separated list for multiple values, with valuesly formatted as `key:value` pairs.
          attribute? :deploymentTags, Types::String

          # Comments or notes about the deployment.
          attribute? :deploymentComments, Types::String

          # @param deployment [DeploymentAccumulator::Deployment] the accumulated deployment metadata
          #   whose `ensure_timezone` method applies the forced UTC offset, site timezone, or UTC fallback.
          # @param should_obfuscate [Boolean] whether to obfuscate the latitude and longitude values for the deployment
          # @return [Deployment] the deployment struct with the mapped values
          def self.mapping(deployment, user:, should_obfuscate:)
            site = deployment.site

            coordinate_uncertainty = site.coordinate_uncertainty_meters(user: user, should_obfuscate: should_obfuscate)

            # Because we are treating site as a single deployment, the same identifier is used for both deploymentID and locationID.
            attributes = {
              deploymentID: site.global_identifier,
              locationID: site.global_identifier,
              locationName: site.name,
              latitude: site.public_latitude(user: user, should_obfuscate: should_obfuscate),
              longitude: site.public_longitude(user: user, should_obfuscate: should_obfuscate),
              coordinateUncertainty: coordinate_uncertainty,
              deploymentStart: deployment.ensure_timezone(deployment.start),
              deploymentEnd: deployment.ensure_timezone(deployment.end),
              deploymentTags: tags(site, coordinate_uncertainty:, user: user, should_obfuscate: should_obfuscate)
            }.compact

            Deployment.new(attributes)
          end

          # Using tags to include additional information (semi-structured)
          # as key:value pairs, separated by a pipe character (|).
          # See https://camtrap-dp.tdwg.org/faq/#measurements
          #
          # Return a string with the following two tags:
          # (1) If the coordinates are coordinatesObfuscated: true/false, and
          # (2) dataGeneralizations: <uncertainty information>.
          def self.tags(site, coordinate_uncertainty:, user:, should_obfuscate:, tags: [])
            obfuscated = should_obfuscate.nil? ? site.location_obfuscated(user: user) : should_obfuscate

            text = ''
            if coordinate_uncertainty.nil?
              text += 'coordinate uncertainty is unknown'
              text += ' because the obfuscation uncertainty is unknown' if obfuscated && site.custom_obfuscated_location
            else
              m_u_m = site.measurement_uncertainty_meters
              text += "coordinates have an assumed measurement uncertainty of #{m_u_m} meters"
              text += " and an obfuscation uncertainty of #{coordinate_uncertainty - m_u_m} meters" if obfuscated
            end

            tags << ['coordinatesObfuscated', obfuscated.to_s].join(':')
            tags << ['dataGeneralizations', text].join(':')
            tags.join(' | ')
          end
        end
      end
    end
  end
end
