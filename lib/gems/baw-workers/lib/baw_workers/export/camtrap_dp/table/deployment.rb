module BawWorkers
  module Export
    module CamtrapDp
      module Table
        # Represents a row in the `deployment` table of the Camtrap Data Package.
        #
        # Attributes are defined in schema order (required for CSV validation).
        class Deployment < ::Dry::Struct
          Types = BawWorkers::Dry::Types

          # Unique identifier of the deployment.
          attribute :deploymentID, Types::Coercible::String

          # Identifier of the deployment location.
          attribute? :locationID, Types::Coercible::String.optional

          # Name given to the deployment location.
          attribute? :locationName, Types::String.optional

          # Latitude of the deployment location in decimal degrees, using the WGS84 datum.
          attribute :latitude, Types::Nominal::Decimal

          # Longitude of the deployment location in decimal degrees, using the WGS84 datum.
          attribute :longitude, Types::Nominal::Decimal

          # Horizontal distance from the given `latitude` and `longitude` describing the smallest circle containing the deployment location. Expressed in meters. Especially relevant when coordinates are rounded to protect sensitive species.
          attribute? :coordinateUncertainty, Types::Integer.optional

          # Elevation (altitude, usually above sea level) in meters
          attribute? :elevation, Types::Integer.optional

          # Date and time at which the deployment was started. Formatted as an ISO 8601 string with timezone designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
          attribute :deploymentStart, Types::UtcTimeSeconds

          # Date and time at which the deployment was ended. Formatted as an ISO 8601 string with timezone designator (`YYYY-MM-DDThh:mm:ssZ` or `YYYY-MM-DDThh:mm:ss¬±hh:mm`).
          attribute :deploymentEnd, Types::UtcTimeSeconds

          # Name or identifier of the person or organization that deployed the device.
          attribute? :setupBy, Types::String.optional

          # Identifier of the device used for the deployment (e.g. the device device serial number).
          attribute? :deviceID, Types::String.optional

          # Manufacturer and model of the device. Formatted as `manufacturer-model`.
          attribute? :deviceModel, Types::String.optional

          # The substrate to which the device is mounted.
          attribute? :devicePlatform,
            Types::String.enum('buoy', 'vegetation', 'building', 'structure', 'pole', 'unattached').optional

          # Predefined duration after detection when further activity is ignored. Expressed in seconds.
          attribute? :deviceDelay, Types::Integer.optional

          # Height at which the device was deployed. Expressed in meters. Not to be combined with `deviceDepth`.
          attribute? :deviceHeight, Types::Coercible::Float.optional

          # Depth at which the device was deployed. Expressed in meters. Not to be combined with `deviceHeight`.
          attribute? :deviceDepth, Types::Coercible::Float.optional

          # Angle at which the device was deployed in the vertical plane. Expressed in degrees, with `-90` facing down, `0` horizontal and `90` facing up.
          attribute? :deviceTilt, Types::Integer.optional

          # Angle at which the device was deployed in the horizontal plane. Expressed in decimal degrees clockwise from north, with values ranging from `0` to `360`: `0` = north, `90` = east, `180` = south, `270` = west.
          attribute? :deviceHeading, Types::Integer.optional

          # Description of the recording schedule.
          attribute? :recordingSchedule, Types::String.optional

          # Maximum distance at which the device can reliably detect activity. Expressed in meters. Typically measured by having a human move in front of the device.
          attribute? :detectionDistance, Types::Coercible::Float.optional

          # `true` if bait was used for the deployment. More information can be provided in `tags` or `comments`.
          attribute? :baitUse, Types::Bool.optional

          # Type of the feature (if any) associated with the deployment.
          attribute? :locationType,
            Types::String.enum('roadPaved', 'roadDirt', 'trailHiking', 'trailGame', 'roadUnderpass', 'roadOverpass', 'roadBridge',
              'culvert', 'burrow', 'nestSite', 'carcass', 'waterSource', 'fruitingTree').optional

          # Short characterization of the habitat at the deployment location.
          attribute? :habitat, Types::String.optional

          # Deployment group(s) associated with the deployment. Deployment groups can have a spatial (arrays, grids, clusters), temporal (sessions, seasons, months, years) or other context. Formatted as a pipe (`|`) separated list for multiple values, with values preferably formatted as `key:value` pairs.
          attribute? :deploymentGroups, Types::String.optional

          # Tag(s) associated with the deployment. Formatted as a pipe (`|`) separated list for multiple values, with values optionally formatted as `key:value` pairs.
          attribute? :deploymentTags, Types::String.optional

          # Comments or notes about the deployment.
          attribute? :deploymentComments, Types::String.optional

          # @param deployment [DeploymentAccumulator::Deployment] the accumulated deployment metadata
          #   whose `export_time` method applies the forced UTC offset, site timezone, or UTC fallback.
          # @param should_obfuscate [Boolean] whether to obfuscate the latitude and longitude values for the deployment
          # @return [Deployment] the deployment struct with the mapped values
          def self.mapping(deployment, should_obfuscate:)
            site = deployment.site

            # Because we are treating site as a single deployment, site id is used for both the deploymentID and locationID.
            Deployment.new(
              deploymentID: site.id,
              locationID: site.id,
              locationName: site.name,
              latitude: (should_obfuscate ? site.obfuscated_latitude : site.latitude),
              longitude: (should_obfuscate ? site.obfuscated_longitude : site.longitude),
              coordinateUncertainty: nil,
              deploymentStart: deployment.export_time(deployment.start),
              deploymentEnd: deployment.export_time(deployment.end)
            )
          end
        end
      end
    end
  end
end
