# frozen_string_literal: true

# TODO: sources field : open ecoacoustics
#   we have the name and title in settings file
#   ecosounds.org
module BawWorkers
  module Export
    module CamtrapDp
      module Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties
        class Package < Base
          attribute :profile, Types::UrlOrPath
          attribute :resources, Types::Array.of(Resource)
          attribute :created, Types::UtcTimeSeconds
          attribute :contributors, Types::Array.of(Contributor)
          attribute :project, Project
          attribute :spatial, Types::GeoJSON
          attribute :temporal, Temporal
          attribute :taxonomic, Types::Array.of(Taxonomic)

          attribute? :name, Types::String
          attribute? :id, Types::String

          attribute? :title, Types::String
          attribute? :description, Types::String
          attribute? :version, Types::String
          attribute? :keywords, Types::Array.of(Types::String)
          attribute? :image, Types::String
          attribute? :homepage, Types::String
          attribute? :sources, Types::Array.of(Source)
          attribute? :licenses, Types::Array.of(License)
          attribute? :bibliographicCitation, Types::String
          attribute? :coordinatePrecision, Types::Float
          attribute? :relatedIdentifiers, Types::Array.of(RelatedIdentifier)
          attribute? :references, Types::Array.of(Types::String)
        end
      end
    end
  end
end
