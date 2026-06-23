# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class PackageMetadata
        def self.build(deployments:, scientific_names:, options:)
          temporal = temporal_coverage(deployments)

          Descriptor::Package.new(
            profile: Profile::PROFILE_PATH,
            name: nil,
            id: nil,
            created: Time.current.utc.iso8601,
            title: nil,
            contributors: options.contributors,
            project: project_descriptor(options),
            spatial: spatial_coverage(deployments, options),
            temporal: Descriptor::Temporal.new(
              start: temporal[:start],
              end: temporal[:end]
            ),
            taxonomic: taxonomic_coverage(scientific_names)
          )
        end

        def self.project_descriptor(options)
          Descriptor::Project.new(
            title: options.project_title,
            description: nil,
            path: nil,
            samplingDesign: options.project_sampling_design,
            captureMethod: options.project_capture_method,
            individualAnimals: options.project_individual_animals,
            observationLevel: options.observation_level,
            licenses: nil
          )
        end

        def self.temporal_coverage(deployments)
          return { start: '', end: '' } if deployments.empty?

          overall_start = deployments.map(&:start).min
          overall_end = deployments.map(&:end).max

          { start: overall_start.utc.iso8601, end: overall_end.utc.iso8601 }
        end

        def self.spatial_coverage(deployments, options)
          return {} if deployments.empty?

          coords = deployments.map { |deployment|
            site = deployment.site
            lat = (options.should_obfuscate ? site.obfuscated_latitude : site.latitude).to_f
            lon = (options.should_obfuscate ? site.obfuscated_longitude : site.longitude).to_f
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
