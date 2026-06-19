# frozen_string_literal: true

# TODO: sources field : open ecoacoustics
#   we have the name and title in settings file
#   ecosounds.org
module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        class Package < Descriptor
          attribute :profile, Types::String
          attribute :resources, Types::Array.of(Resource).default(Resource::DEFAULT_RESOURCES)
          attribute :created, Types::String
          attribute :contributors, Types::Array.of(Contributor)
          attribute :project, Project
          attribute :spatial, Types::Hash # Types::GeoJSON
          attribute :temporal, Temporal
          attribute :taxonomic, Types::Array.of(Taxonomic)

          attribute? :name, Types::String.optional
          attribute? :id, Types::String.optional
          attribute? :title, Types::String.optional
          attribute? :description, Types::String.optional
          attribute? :version, Types::String.optional
          attribute? :keywords, Types::Array.of(Types::String).optional
          attribute? :image, Types::String.optional
          attribute? :homepage, Types::String.optional
          attribute? :sources, Types::Array.of(Source).optional
          attribute? :licenses, Types::Array.of(License).optional
          attribute? :bibliographicCitation, Types::String.optional
          attribute? :coordinatePrecision, Types::Float.optional
          attribute? :relatedIdentifiers, Types::Array.of(RelatedIdentifier).optional
          attribute? :references, Types::Array.of(Types::String).optional
        end
      end
    end
  end
end
