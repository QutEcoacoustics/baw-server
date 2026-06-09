# frozen_string_literal: true

require 'zip'

# The CamtrapDp export module is responsible for generating a Camtrap Data Package export from a given filter of taggings.
# It generates a zip file containing the CSV tables the datapackage.json file describing the package.
#
# NOTE: ALA exports will be limited to a single project, enforced upstream, not in this module.
# NOTE: :should_obfuscate option is respected and the ability to set this will be enforced in the controller
module BawWorkers
  module Export
    module CamtrapDp
      class Exporter
        # Required fields that we can't currently generate or pull from the database
        RequiredExporterOptions = Data.define(
          :should_obfuscate,
          :contributors,
          :project_capture_method,
          :project_individual_animals,
          :observation_level,
          :project_sampling_design,
          :project_title
        )

        PROFILE = 'https://raw.githubusercontent.com/camera-traps/bioacoustics/refs/heads/main/camtrap-dp/1.0.2/camtrap-dp-profile-acoustic.json'
        DATAPACKAGE_JSON = 'datapackage.json'
        OBSERVATIONS_CSV = 'observations.csv'
        DEPLOYMENTS_CSV = 'deployments.csv'
        MEDIA_CSV = 'media.csv'
        ZIP_FILENAME = 'dp.zip'

        def initialize(filter, **exporter_options)
          @filter = validate_filter(filter)
          @options = RequiredExporterOptions.new(**exporter_options)
        end

        # @yield [Hash manifest] manifest contains metadata about the generated export, including the path to the zip file
        # @return the result of block
        def call(&block)
          raise ArgumentError, 'block is required' unless block_given?

          # site_id => { site:, min_start:, max_end: } only two timestamps + site object per unique site
          site_deployments = {}
          ar_ids = Set.new
          scientific_names = Set.new
          # Cache site_id => file_public so we don't re-check permissions for every tagging.
          # file_public is true if any of the site's projects has a permission that grants
          # anonymous or logged-in access (i.e. the media isn't restricted to named users).
          site_file_public = {}

          observations_writer = csv_open(files[:observations], Observation)
          deployments_writer = csv_open(files[:deployments], Deployment)
          media_writer = csv_open(files[:media], Media)

          # Streaming approach with find_each avoids pulling all records into memory at once.
          # Deployments are written after the loop because deployment_start/end require the
          # min/max across all audio recordings for each site in the result set.

          # comment why to explain / try again
          bullet_was_enabled = defined?(Bullet)
          Bullet.enable = false

          included.find_each do |t|
            observations_writer << Observation.mapping(t).full_values

            site = t.audio_event.audio_recording.site
            ar   = t.audio_event.audio_recording
            ar_end = ar.recorded_date + ar.duration_seconds.to_f.seconds # TODO: model should know how to calculate its end date (so audiorecording.recorded_end_date or smth, match the existing name pattern e.g. arel helpers)

            # existing site, update running min/max; else new site, init min/max with current recording's start/end
            # and determine if the media files for this site should be considered public based on project permissions
            if site_deployments.key?(site.id)
              if ar.recorded_date < site_deployments[site.id][:min_start]
                site_deployments[site.id][:min_start] = ar.recorded_date
              end
              site_deployments[site.id][:max_end] = ar_end if ar_end > site_deployments[site.id][:max_end]
            else
              site_deployments[site.id] = {
                site: site,
                min_start: ar.recorded_date,
                max_end: ar_end,
                file_public: public_site?(site)
              }
            end

            media_writer << Media.mapping(ar, site_deployments[site.id][:file_public]).full_values if ar_ids.add?(ar.id)
            scientific_names.add(t.tag.text)
          end

          # Now we have min/max per site write all deployment rows
          site_deployments.each_value do |entry|
            deployments_writer << Deployment.mapping(entry[:site],
              deployment_start: entry[:min_start],
              deployment_end: entry[:max_end],
              should_obfuscate: @options.should_obfuscate).full_values
          end

          temporal = temporal_coverage(site_deployments)

          # TODO: datapackage baw and gem is confusing. also, add _ in baw dp

          datapackage = Datapackage::PackageSchema.new(
            profile: PROFILE,
            name: nil,
            id: nil,
            created: Time.now.utc.iso8601,
            title: nil,
            contributors: @options.contributors,
            project: Datapackage::ProjectSchema.new(
              title: @options.project_title,
              description: nil,
              path: nil,
              samplingDesign: @options.project_sampling_design,
              captureMethod: @options.project_capture_method,
              individualAnimals: @options.project_individual_animals,
              observationLevel: @options.observation_level,
              licenses: nil # TODO: licenses is optional but if present requires 2 licenses; one for the content of the package, one for the media files
            ),
            spatial: spatial_coverage(site_deployments),
            temporal: Datapackage::TemporalSchema.new(
              start: temporal[:start],
              end: temporal[:end]
            ),
            taxonomic: scientific_names.sort.map { |name| Datapackage::TaxonomicSchema.new(scientificName: name) }
          )

          File.write(files[:datapackage], JSON.pretty_generate(datapackage.to_h))

          close_writers(observations_writer, deployments_writer, media_writer)
          zip

          result = block.call(manifest)
          result
        ensure
          Bullet.enable = true if bullet_was_enabled
          close_writers(observations_writer, deployments_writer, media_writer)
          cleanup
        end

        private

        # TODO: perhaps move to permissions model as a scoped query
        # Check if the site has public media files (i.e. any project it belongs to has permissions that allow
        # anonymous or logged-in access).
        # @param [Site] site
        def public_site?(site)
          site.projects.any? { |proj|
            proj.permissions.any? { |perm| perm.allow_anonymous || perm.allow_logged_in }
          }
        end

        def close_writers(*writers)
          writers.each do |writer|
            writer.close unless writer.nil? || writer.closed?
          end
        end

        def cleanup
          FileUtils.remove_entry(temp_dir) if Dir.exist?(temp_dir)
        end

        def validate_filter(filter)
          message = 'Expected filter to be '
          raise ArgumentError, message + 'ActiveRecord::Relation' unless filter.is_a?(::ActiveRecord::Relation)
          raise ArgumentError, message + 'Tagging relation' unless filter.klass == Tagging

          filter
        end

        def included
          @included ||= @filter
            .includes(:tag, audio_event: [:provenance, { audio_recording: { site: { projects: :permissions } } }])
        end

        def has_zero_area?(min_lon, max_lon, min_lat, max_lat)
          min_lon == max_lon || min_lat == max_lat
        end

        def spatial_coverage(site_deployments)
          return {} if site_deployments.empty?

          coords = site_deployments.values.map { |entry|
            site = entry[:site]
            lat = (@options.should_obfuscate ? site.obfuscated_latitude : site.latitude).to_f
            lon = (@options.should_obfuscate ? site.obfuscated_longitude : site.longitude).to_f
            [lon, lat]
          }

          return { type: 'Point', coordinates: coords.first } if coords.size == 1

          lons = coords.map(&:first)
          lats = coords.map(&:last)
          min_lon, max_lon = lons.minmax
          min_lat, max_lat = lats.minmax

          # Degenerate bbox (all sites share the same lat or lon) use unique points instead
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

        def temporal_coverage(site_deployments)
          return { start: '', end: '' } if site_deployments.empty?

          overall_start = site_deployments.values.map { |e| e[:min_start] }.min
          overall_end   = site_deployments.values.map { |e| e[:max_end] }.max

          { start: overall_start.utc.iso8601, end: overall_end.utc.iso8601 }
        end

        def temp_dir
          @temp_dir ||= Pathname.new(Dir.mktmpdir('exporter_', Pathname.new(BawWorkers::Config.temp_dir)))
        end

        def datapackage_path = temp_dir.join('dp').tap { Dir.mkdir(_1) unless Dir.exist?(_1) }

        def zip_path = datapackage_path.sub_ext('.zip')

        def files
          @files = { observations: datapackage_path.join(OBSERVATIONS_CSV),
                     deployments: datapackage_path.join(DEPLOYMENTS_CSV),
                     media: datapackage_path.join(MEDIA_CSV),
                     datapackage: datapackage_path.join(DATAPACKAGE_JSON) }
        end

        # Open a table resource CSV for writing
        # @param [String] path the file path to write to
        # @param [#attribute_names] klass or object with #attribute_names to use as headers
        # @return [CSV] an open CSV IO object in write-only mode
        def csv_open(path, klass)
          raise ArgumentError, 'missing #attribute_names on klass' unless klass.respond_to?(:attribute_names)

          CSV.open(path, 'w', write_headers: true, headers: klass.attribute_names, force_quotes: true)
        end

        def zip
          Zip::File.open(zip_path, create: true) do |zip|
            files.each_value { |path| zip.add(path.basename.to_s, path) }
          end
        end

        def manifest
          { datapackage_path: datapackage_path,
            zip_path: zip_path,
            file_stats: files.transform_values { |path|
              { size: path.size, mtime: path.mtime }
            } }
        end
      end
    end
  end
end
