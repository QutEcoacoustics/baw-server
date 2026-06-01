# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      # attribute? makes keys optional. They get value of nil, which can be a problem if the type doesn't allow nil.
      # Two options:
      # add default value to the type => don't nneed to use attribute?, missing key will be coerced to default value. I will use attribute? regardless for clarity
      # Or, use attribute? with an .optional type, which allows nil values.
      # For types with default values, the transform_type method will coerce nil to undefined, which will trigger the default value
      # If an attribute has a default value, it won't be possible to set it as nil, it will be coerced to the default value.
      module Datapackage
        Types = BawWorkers::Dry::Types

        class DpStruct < ::Dry::Struct
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

        # The value for the schema property on a resource MUST be an object representing the schema OR a string that identifies
        # the location of the schema. If a string it must be a url-or-path as defined above, that is a fully qualified http URL or a relative POSIX path.
        TABLE_SCHEMA_DIR = File.join(__dir__, 'profile')
        TABLE_SCHEMA_FILE_SUFFIX = '-table-schema-acoustic.json'

        def self.load_table_schema(name)
          load_schema(File.join(TABLE_SCHEMA_DIR, "#{name}#{TABLE_SCHEMA_FILE_SUFFIX}"))
        end

        def self.load_schema(path) = JSON.parse(File.read(path), symbolize_names: true)

        STATIC_RESOURCES = [
          ResourceSchema.new(name: 'deployments',  path: 'deployments.csv',  schema: load_table_schema('deployments')), #nolint
          ResourceSchema.new(name: 'media',        path: 'media.csv',        schema: load_table_schema('media')),
          ResourceSchema.new(name: 'observations', path: 'observations.csv', schema: load_table_schema('observations')) #noline
        ].freeze

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
          attribute :individualAnimals, Types::Bool

          # Confusingly 'interval' is allowed for the observation table field but not for the package metadata field
          attribute :observationLevel, Types::Array.of(Types::String.default('media').enum('media', 'event'))
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

        class LicenseSchema < DpStruct
          attribute :name, Types::String
          attribute? :path, Types::String.optional
          attribute? :title, Types::String.optional
          attribute :scope, Types::String.enum('data', 'media')
        end

        class RelatedIdentifierSchema < DpStruct
          attribute :relationType, Types::String
          attribute :relatedIdentifier, Types::String
          attribute? :resourceTypeGeneral, Types::String.optional
          attribute :relatedIdentifierType, Types::String
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
