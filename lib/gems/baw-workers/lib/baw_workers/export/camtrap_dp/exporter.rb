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

        PROFILE = 'https://raw.githubusercontent.com/tdwg/camtrap-dp/1.0/camtrap-dp-profile.json'

        DATAPACKAGE_JSON = 'datapackage.json'
        OBSERVATIONS_CSV = 'observations.csv'
        DEPLOYMENTS_CSV = 'deployments.csv'
        MEDIA_CSV = 'media.csv'

        def initialize(filter, **exporter_options)
          @filter = validate_filter(filter)
          @options = RequiredExporterOptions.new(**exporter_options)

          dir = Pathname.new(BawWorkers::Config.temp_dir)
          @files = { observations: dir.join(OBSERVATIONS_CSV),
                     deployments: dir.join(DEPLOYMENTS_CSV),
                     media: dir.join(MEDIA_CSV),
                     datapackage: dir.join(DATAPACKAGE_JSON) }
          @zip_path = dir.join("dp_#{SecureRandom.uuid}.zip")
        end

        attr_reader :files, :zip_path

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

        def call
          # site_id => { site:, min_start:, max_end: } — only two timestamps + site object per unique site
          site_deployments = {}
          ar_ids = Set.new
          scientific_names = Set.new

          observations_writer = csv_open(files[:observations], Observation)
          deployments_writer = csv_open(files[:deployments], Deployment)
          media_writer = csv_open(files[:media], Media)

          # Cache site_id => file_public so we don't re-check permissions for every tagging.
          # file_public is true if any of the site's projects has a permission that grants
          # anonymous or logged-in access (i.e. the media isn't restricted to named users).
          site_file_public = {}

          # Streaming approach with find_each avoids pulling all records into memory at once.
          # Deployments are written after the loop because deployment_start/end require the
          # min/max across all audio recordings for each site in the result set.
          bullet_was_enabled = defined?(Bullet)
          Bullet.enable = false

          included.find_each do |t|
            observations_writer << Observation.mapping(t).full_values

            site = t.audio_event.audio_recording.site
            ar   = t.audio_event.audio_recording
            ar_end = ar.recorded_date + ar.duration_seconds.to_f.seconds

            if site_deployments.key?(site.id)
              entry = site_deployments[site.id]
              entry[:min_start] = ar.recorded_date if ar.recorded_date < entry[:min_start]
              entry[:max_end]   = ar_end if ar_end > entry[:max_end]
            else
              site_file_public[site.id] = site.projects.any? { |proj|
                proj.permissions.any? { |perm| perm.allow_anonymous || perm.allow_logged_in }
              }
              site_deployments[site.id] = { site: site, min_start: ar.recorded_date, max_end: ar_end }
            end

            media_writer << Media.mapping(ar, site_file_public[site.id]).full_values if ar_ids.add?(ar.id)
            scientific_names.add(t.tag.text)
          end

          observations_writer.close
          media_writer.close

          # Now we have min/max per site write all deployment rows
          site_deployments.each_value do |entry|
            deployments_writer << Deployment.mapping(entry[:site],
              deployment_start: entry[:min_start],
              deployment_end: entry[:max_end],
              should_obfuscate: @options.should_obfuscate).full_values
          end

          deployments_writer.close

          temporal = temporal_coverage(site_deployments)
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

          zip
          file_stats = files.transform_values { |path| { size: path.size, mtime: path.mtime } }
          { manifest: { zip_path: zip_path, file_stats: file_stats } }
        ensure
          Bullet.enable = true if bullet_was_enabled
          [observations_writer, deployments_writer, media_writer].each do |writer|
            writer.close unless writer.nil? || writer.closed?
          end
        end

        private

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

          if coords.size == 1
            return {
              type: 'Feature',
              geometry: { type: 'Point', coordinates: coords.first }
            }
          end

          lons = coords.map(&:first)
          lats = coords.map(&:last)
          min_lon, max_lon = lons.minmax
          min_lat, max_lat = lats.minmax

          # Degenerate bbox (all sites share the same lat or lon) use unique points instead
          geometry = if has_zero_area?(min_lon, max_lon, min_lat, max_lat)
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

          { type: 'Feature', geometry: geometry }
        end

        def temporal_coverage(site_deployments)
          return { start: '', end: '' } if site_deployments.empty?

          overall_start = site_deployments.values.map { |e| e[:min_start] }.min
          overall_end   = site_deployments.values.map { |e| e[:max_end] }.max

          { start: overall_start.utc.iso8601, end: overall_end.utc.iso8601 }
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
      end
    end
  end
end
