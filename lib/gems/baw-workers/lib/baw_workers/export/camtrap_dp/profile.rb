# frozen_string_literal: true

require 'fileutils'
require 'open-uri'
require 'uri'

module BawWorkers
  module Export
    module CamtrapDp
      module Profile
        SOURCE_URL = 'https://raw.githubusercontent.com/camera-traps/bioacoustics/e4b4722fb453f5ca39c39ea3c4f348e9953f0084/camtrap-dp/1.0.2/'
        ASSET_FILES = {
          profile: 'camtrap-dp-profile-acoustic.json',
          deployments: 'deployments-table-schema-acoustic.json',
          media: 'media-table-schema-acoustic.json',
          observations: 'observations-table-schema-acoustic.json'
        }

        DIRECTORY = File.join(__dir__, 'profile_assets')
        PROFILE_PATH = File.join(DIRECTORY, ASSET_FILES[:profile])
        LOCAL_VALIDATION_PROFILE_PATH = PROFILE_PATH.gsub('.json', '.local.json')

        # References in the camtrap-dp-profile-acoustic.json to be resolved
        EXTERNAL_SCHEMA_REFS = [
          'http://json.schemastore.org/geojson.json',
          'https://specs.frictionlessdata.io/schemas/data-package.json',
          'https://geojson.org/schema/GeoJSON.json'
        ]

        def self.download
          FileUtils.mkdir_p(DIRECTORY)

          ASSET_FILES.each_with_object({}) do |(key, value), hash|
            hash[key] = download_fixture(value)
          end => log

          {
            source_url: SOURCE_URL,
            downloaded_assets: log,
            completed_at: Time.current
          }
        end

        def self.download_fixture(name)
          data = URI.open(File.join(SOURCE_URL, name)).read
          path = File.join(DIRECTORY, name)
          File.write(path, data)
          path
        end

        def self.create_local_validation_profile
          root_profile = JSON.parse(File.read(PROFILE_PATH), symbolize_names: false)
          resolved_refs = EXTERNAL_SCHEMA_REFS.index_with { |ref|
            JSON.parse(URI.open(ref).read, symbolize_names: false)
          }
          resolved_refs.each_value { |schema| schema.delete('$schema') }

          summary = {}
          inlined_profile = inline_known_refs(root_profile, resolved_refs) { |ref| summary[ref] = true }
          inlined_profile.delete('$schema')

          File.write(LOCAL_VALIDATION_PROFILE_PATH, JSON.pretty_generate(inlined_profile))

          {
            local_validation_profile: LOCAL_VALIDATION_PROFILE_PATH,
            external_references_inlined: summary,
            completed_at: Time.current
          }
        end

        def self.inline_known_refs(value, resolved_refs, &block)
          if value.is_a?(Hash) && value.key?('$ref') && resolved_refs.key?(value['$ref'])
            fetched = resolved_refs.fetch(value['$ref'])
            if fetched
              yield value['$ref'] if block_given?
              return inline_known_refs(fetched, resolved_refs, &block)
            end
          end

          return value.transform_values { |child| inline_known_refs(child, resolved_refs, &block) } if value.is_a?(Hash)
          return value.map { |child| inline_known_refs(child, resolved_refs, &block) } if value.is_a?(Array)

          value
        end
      end
    end
  end
end
