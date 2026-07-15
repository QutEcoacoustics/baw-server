# frozen_string_literal: true

require_relative 'errors/camtrap_dp_error'

module BawWorkers
  module Export
    module CamtrapDp
      # Responsible for generating the package descriptor and associated metadata including spatial, temporal, and
      # taxonomic coverage.
      class PackageMetadata
        def self.build(deployments:, scientific_names:, options:)
          temporal = temporal_coverage(deployments)
          project = get_project(deployments)
          licenses = options.emit_project_license ? project_license(project) : nil

          project = Descriptor::Project.new(
            title: project.name,
            description: project.description,
            path: nil,
            samplingDesign: options.project_sampling_design,
            captureMethod: options.project_capture_method,
            individualAnimals: individual_animals,
            observationLevel: observation_level,
            licenses: licenses
          )

          Descriptor::Package.new(
            profile: Profile::PROFILE_PATH.to_s,
            #name:,
            #id:,
            created: Time.current.utc.iso8601,
            # title:,
            contributors: options.contributors,
            project: project,
            spatial: spatial_coverage(deployments, options),
            temporal: Descriptor::Temporal.new(
              start: temporal[:start],
              end: temporal[:end]
            ),
            taxonomic: taxonomic_coverage(scientific_names)
          )
        end

        # Optional title for this specific package, different from the project title
        # def self.package_title =

        # We don't support identifying individual animals currently, so this will always be false. In future, if we
        # add a platform feature to support this, we can make this configurable.
        def self.individual_animals = false

        # We don't distinguish currently, so default to media. In the future, we might be able to merge our 'media'
        # observations (audio_events) into an 'event' observation level, to reduce duplication.
        def self.observation_level = ['media']

        # Return the first project in the deployments, under the assumption packages are scoped to a single project.
        # @param deployments [Array<DeploymentAccumulator::Deployment>]
        # @return [Project]
        def self.get_project(deployments)
          deployments.first&.site&.projects&.first
        end

        # Generate the licenses descriptor from the first project found
        #
        # In the database, existing project licenses are SPDX identifiers. But it's currently a free text field, so we
        # will use string length as a proxy for being an identifier, and raise an error if we encounter something longer
        # than 32 characters. We only store one license per project, so we use the same license for both required
        # scopes: data and media.
        def self.project_license(project)
          project_license = project&.license

          if project_license.nil?
            nil
          elsif project_license.length <= 32
            [Descriptor::License.new(name: project_license, scope: 'data'),
             Descriptor::License.new(name: project_license, scope: 'media')]
          else
            raise Errors::ProjectLicenseError, "Found unsupported custom license (>32 chars): #{project_license}"
          end
        end

        # Calculate descriptor-level temporal coverage from the deployment bounds.
        #
        # Rails TimeWithZone comparisons are based on the UTC instant, but the offset is preserved in the output, so
        # it's possible to have a start / end in different timezones.
        #
        # @param deployments [Array<DeploymentAccumulator::Deployment>]
        # @return [Hash] with `:start` and `:end` keys containing ISO 8601 timestamps
        def self.temporal_coverage(deployments)
          return { start: '', end: '' } if deployments.empty?

          {
            start: deployments.map(&:start).min,
            end: deployments.map(&:end).max
          }
        end

        def self.spatial_coverage(deployments, options)
          return {} if deployments.empty?

          coords = deployments.map { |deployment|
            site = deployment.site
            lat = (options.should_obfuscate ? site.obfuscated_latitude : site.public_latitude)
            lon = (options.should_obfuscate ? site.obfuscated_longitude : site.public_longitude)
            [lon, lat]
          }

          return { type: 'Point', coordinates: coords.first } if coords.size == 1

          lons = coords.map(&:first)
          lats = coords.map(&:last)
          min_lon, max_lon = lons.minmax
          min_lat, max_lat = lats.minmax

          if has_zero_area?(min_lon, max_lon, min_lat, max_lat)
            { type: 'MultiPoint', coordinates: coords.uniq }
          else
            {
              type: 'Polygon',
              coordinates: [[
                [min_lon, min_lat],
                [max_lon, min_lat],
                [max_lon, max_lat],
                [min_lon, max_lat],
                [min_lon, min_lat]
              ]]
            }
          end
        end

        def self.has_zero_area?(min_lon, max_lon, min_lat, max_lat)
          min_lon == max_lon || min_lat == max_lat
        end

        def self.taxonomic_coverage(scientific_names)
          scientific_names.sort.map { |name| Descriptor::Taxonomic.new(scientificName: name) }
        end
      end
    end
  end
end
