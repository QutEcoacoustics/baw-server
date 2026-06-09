# frozen_string_literal: true

require 'open-uri'
require 'uri'
# TODO: sources field : open ecoacoustics
#   we have the name and title in settings file
#   ecosounds.org
module BawWorkers
  module Export
    module CamtrapDp
      module Datapackage
        Types = BawWorkers::Dry::Types

        class DpStruct < ::Dry::Struct
          # Add a compact! step to the usual Dry::Struct#to_h method.
          # We use explicit nil values for optional fields for clarity and maintainability,
          # but null values in JSON output raise type validation errors unless the type allows it.
          def to_h
            self.class.schema.each_with_object({}) do |key, result|
              result[key.name] = ::Dry::Struct::Hashify[self[key.name]] if attributes.key?(key.name)
              result.compact!
            end
          end

          # nil as a value isn’t replaced with a default value for default types. use transform_types to turn
          # all types into constructors which map nil to Dry::Types::Undefined which triggers default values.
          transform_types do |type|
            if type.default?
              type.constructor do |value|
                value.nil? ? Dry::Types::Undefined : value
              end
            else
              type
            end
          end
        end

        class ResourceSchema < DpStruct
          attribute :name,      Types::String
          attribute :path,      Types::URLOrPath # (just the filename in our case, relative to the datapackage root)
          attribute :profile,   Types::String.default('tabular-data-resource') # the resources in camtrap dp are tabular-data-resource - this is fixed
          attribute :format,    Types::String.default('csv')
          attribute :mediatype, Types::String.default('text/csv')
          attribute :encoding,  Types::String.default('utf-8')
          attribute :schema,    Types::Schema # The raw parsed JSON table schema or url-or-path to the schema
        end

        # TODO: rename to schema and rename all refs to this const etc
        # Then run rake to test
        TABLE_SCHEMA_DIR = File.join(__dir__, 'profile')
        TABLE_SCHEMA_FILE_SUFFIX = '-table-schema-acoustic.json'
        PROFILE_FILE = 'camtrap-dp-profile-acoustic.json'
        LOCAL_VALIDATION_PROFILE_FILE = 'camtrap-dp-profile-acoustic.local.json'
        PROFILE_REFS = [
          'http://json.schemastore.org/geojson.json',
          'https://specs.frictionlessdata.io/schemas/data-package.json',
          'https://geojson.org/schema/GeoJSON.json'
        ].freeze

        def self.profile_path = File.join(TABLE_SCHEMA_DIR, PROFILE_FILE)

        def self.local_validation_profile_path = File.join(TABLE_SCHEMA_DIR, LOCAL_VALIDATION_PROFILE_FILE)

        def self.download_profile!(source_url, target_path: profile_path)
          File.write(target_path, URI.open(source_url).read)
          target_path
        end

        # Build a copy of the data profile with known external $refs inlined.
        # This allows running package validation offline.
        def self.create_local_validation_profile(
          source_profile_path: profile_path,
          output_profile_path: local_validation_profile_path
        )
          root_profile = JSON.parse(File.read(source_profile_path), symbolize_names: false)
          resolved_refs = PROFILE_REFS.index_with { |ref| JSON.parse(URI.open(ref).read, symbolize_names: false) }
          resolved_refs.each_key { |key| resolved_refs[key].delete('$schema') }

          inlined_profile = inline_known_refs(root_profile, resolved_refs)
          # Also delete the root $schema to prevent validation against remote meta-schema
          inlined_profile.delete('$schema')
          File.write(output_profile_path, JSON.pretty_generate(inlined_profile))

          {
            profile_path: output_profile_path,
            downloaded_ref_count: resolved_refs.size,
            downloaded_ref_paths: PROFILE_REFS
          }
        end

        def self.inline_known_refs(value, resolved_refs)
          if value.is_a?(Hash) && value['$ref'].is_a?(String) && resolved_refs.key?(value['$ref'])
            return inline_known_refs(resolved_refs.fetch(value['$ref']), resolved_refs)
          end

          return value.transform_values { |child| inline_known_refs(child, resolved_refs) } if value.is_a?(Hash)
          return value.map { |child| inline_known_refs(child, resolved_refs) } if value.is_a?(Array)

          value
        end

        def self.load_table_schema(name)
          load_schema(File.join(TABLE_SCHEMA_DIR, "#{name}#{TABLE_SCHEMA_FILE_SUFFIX}"))
        end

        def self.load_schema(path) = JSON.parse(File.read(path), symbolize_names: true)

        STATIC_RESOURCES = [
          ResourceSchema.new(name: 'deployments',  path: 'deployments.csv',  schema: load_table_schema('deployments')), #nolint
          ResourceSchema.new(name: 'media',        path: 'media.csv',        schema: load_table_schema('media')),
          ResourceSchema.new(name: 'observations', path: 'observations.csv', schema: load_table_schema('observations')) #noline
        ].freeze

        # Generate automatic + merge extra
        # TODO: all project owners should be something in the array, and all tagging creators should be as well ('contributor') - even verification creators, plus optional add more in from param
        # Should be able to have a list of users and we can map a user to a contributor schema

        class ContributorSchema < DpStruct
          attribute :title, Types::String
          attribute :role, Types::Role

          attribute? :email, Types::String.optional
          attribute? :path, Types::String.optional
          attribute? :organization, Types::String.optional
        end

        class ProjectSchema < DpStruct
          attribute :title, Types::String
          attribute :samplingDesign, Types::SamplingDesign
          attribute :captureMethod, Types::Array.of(Types::CaptureMethod)
          attribute :individualAnimals, Types::Bool # TODO: just false for now + comment explaining we don't support atm until add platform feature or request

          # Confusingly 'interval' is allowed for the observation table field but not for the package metadata field
          attribute :observationLevel, Types::Array.of(Types::String.default('media').enum('media', 'event')) # TODO: just default to media, we don't distinguish. In future might be able to merge things to reduce duplication
          attribute? :id, Types::String.optional
          attribute? :acronym, Types::String.optional
          attribute? :description, Types::String.optional
          attribute? :path, Types::String.optional
          attribute? :protocolType, Types::String.default('acoustic').enum('camera-trapping', 'acoustic')
          attribute? :classificationEffort, Types::String.optional
        end

        class TemporalSchema < DpStruct
          attribute :start, Types::String
          attribute :end, Types::String
        end

        class TaxonomicSchema < DpStruct
          attribute :scientificName, Types::String
          attribute? :taxonID, Types::String.optional
          attribute? :taxonRank, Types::TaxonRank.optional
          attribute? :kingdom, Types::String.optional
          attribute? :phylum, Types::String.optional
          attribute? :class, Types::String.optional
          attribute? :order, Types::String.optional
          attribute? :family, Types::String.optional
          attribute? :genus, Types::String.optional
          attribute? :vernacularNames, Types::Hash.optional
        end

        class SourceSchema < DpStruct
          attribute? :title, Types::String.optional
          attribute? :path, Types::String.optional
          attribute? :email, Types::String.optional
          attribute? :version, Types::String.optional
        end

        # TODO: provide same license for both
        class LicenseSchema < DpStruct
          attribute :name, Types::String
          attribute? :path, Types::String.optional
          attribute? :title, Types::String.optional
          attribute :scope, Types::String.enum('data', 'media')
        end

        class RelatedIdentifierSchema < DpStruct
          attribute :relationType, Types::String
          attribute :relatedIdentifier, Types::String
          attribute :relatedIdentifierType, Types::String
          attribute? :resourceTypeGeneral, Types::String.optional
        end

        class PackageSchema < DpStruct
          attribute :profile, Types::String
          attribute :resources, Types::Array.of(ResourceSchema).default(STATIC_RESOURCES)
          attribute :created, Types::String
          attribute :contributors, Types::Array.of(ContributorSchema)
          attribute :project, ProjectSchema
          attribute :spatial, Types::Hash # Types::GeoJSON
          attribute :temporal, TemporalSchema
          attribute :taxonomic, Types::Array.of(TaxonomicSchema)

          attribute? :name, Types::String.optional
          attribute? :id, Types::String.optional
          attribute? :title, Types::String.optional
          attribute? :description, Types::String.optional
          attribute? :version, Types::String.optional
          attribute? :keywords, Types::Array.of(Types::String).optional
          attribute? :image, Types::String.optional
          attribute? :homepage, Types::String.optional
          attribute? :sources, Types::Array.of(SourceSchema).optional
          attribute? :licenses, Types::Array.of(LicenseSchema).optional
          attribute? :bibliographicCitation, Types::String.optional
          attribute? :coordinatePrecision, Types::Float.optional
          attribute? :relatedIdentifiers, Types::Array.of(RelatedIdentifierSchema).optional
          attribute? :references, Types::Array.of(Types::String).optional
        end
      end
    end
  end
end
