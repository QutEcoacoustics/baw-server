# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        class Resource < Descriptor
          attribute :name, Types::String
          attribute :path, Types::UrlOrPath

          # The resources in camtrap-dp are tabular-data-resources, so this is a fixed value.
          attribute :profile, Types::String.default('tabular-data-resource')
          attribute :format, Types::String.default('csv')
          attribute :mediatype, Types::String.default('text/csv')
          attribute :encoding, Types::String.default('utf-8')

          # The raw parsed JSON table schema or url-or-path to the schema
          attribute :schema, Types::Schema

          def self.load_table_schema(name)
            load_schema(File.join(Profile::DIRECTORY, Profile::ASSET_FILES[name.to_s.to_sym]))
          end

          def self.load_schema(path) = JSON.parse(File.read(path), symbolize_names: true)

          DEFAULT_RESOURCES = [
            new(name: 'deployments', path: DEPLOYMENTS_FILENAME.to_s, schema: load_table_schema(:deployments)),
            new(name: 'media', path: MEDIA_FILENAME.to_s, schema: load_table_schema(:media)),
            new(name: 'observations', path: OBSERVATIONS_FILENAME.to_s, schema: load_table_schema(:observations))
          ].freeze
        end
      end
    end
  end
end
