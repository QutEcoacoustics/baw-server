# frozen_string_literal: true

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
        README_PATH = File.join(DIRECTORY, 'README.md')
        PROFILE_PATH = File.join(DIRECTORY, ASSET_FILES[:profile])
        LOCAL_VALIDATION_PROFILE_PATH = PROFILE_PATH.gsub('.json', '.local.json')

        # References in the camtrap-dp-profile-acoustic.json to be resolved
        EXTERNAL_SCHEMA_REFS = [
          'http://json.schemastore.org/geojson.json',
          'https://specs.frictionlessdata.io/schemas/data-package.json',
          'https://geojson.org/schema/GeoJSON.json'
        ]

        # Download the Profile::ASSET_FILES into the Profile::DIRECTORY
        # @return [Hash] manifest including the downloaded assets with their local paths.
        def self.download
          FileUtils.mkdir_p(DIRECTORY)

          ASSET_FILES.each_with_object({}) do |(key, value), hash|
            hash[key] = download_fixture(value)
          end => downloaded_assets

          {
            source_url: SOURCE_URL,
            downloaded_assets: downloaded_assets,
            completed_at: Time.current
          }
        end

        # Download files from Profile::SOURCE_URL into the Profile::DIRECTORY.
        # @param name [String] the filename to download; a value in Profile::ASSET_FILES
        # @return [String] the file path of the downloaded file relative to the application root
        def self.download_fixture(name)
          data = URI.open(File.join(SOURCE_URL, name)).read
          path = File.join(DIRECTORY, name)
          File.write(path, data)
          Pathname.new(path).relative_path_from(BawApp.root)
        end

        # Create a local version of the profile with known external $ref schemas inlined, for use in tests without network access.
        # The return manifest includes whether each reference was successfully inlined, which can be used to detect
        # profile changes that require an update to EXTERNAL_SCHEMA_REFS.
        def self.create_local_validation_profile
          root_profile = JSON.parse(File.read(PROFILE_PATH), symbolize_names: false)

          # Fetch the external schemas in EXTERNAL_SCHEMA_REFS and store them in a hash keyed by their URI, with the
          # $schema field removed since it can cause JSON validation issues in the DataPackage gem.
          resolved_refs = EXTERNAL_SCHEMA_REFS.index_with { |ref|
            JSON.parse(URI.open(ref).read, symbolize_names: false)
          }
          resolved_refs.each_value { |schema| schema.delete('$schema') }

          successfully_inlined = {}
          inlined_profile = inline_known_refs(root_profile, resolved_refs) { |ref| successfully_inlined[ref] = true }
          inlined_profile.delete('$schema')

          File.write(LOCAL_VALIDATION_PROFILE_PATH, JSON.pretty_generate(inlined_profile))

          {
            local_validation_profile: LOCAL_VALIDATION_PROFILE_PATH,
            external_references_inlined: successfully_inlined,
            completed_at: Time.current
          }
        end

        # Recursively traverse the profile and inline any $ref's that match a key in resolved_refs, replacing it with
        # the corresponding value.
        #
        # @param value [Object] the current value to check for $ref; can be a Hash, Array, or other
        # @param resolved_refs [Hash] a hash of known $ref URIs to their resolved schema objects
        # @return [Hash] the profile with known $ref values inlined
        # @yield [ref] an optional block that is called with each successfully inlined $ref URI
        def self.inline_known_refs(value, resolved_refs, &block)
          # If the value is a hash, check if it has a $ref key that matches a key in resolved_refs
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

        def self.add_readme_section(heading, result, sections: [])
          [*sections, "# #{heading}:\n\n#{result.pretty_inspect}"]
        end

        def self.write_readme(sections)
          File.write(README_PATH, sections.join("\n\n"))
        end
      end
    end
  end
end
