# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      module Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/taxonomic
        class Taxonomic < Base
          attribute :scientificName, Types::String
          attribute? :taxonID, Types::String
          attribute? :taxonRank, Types::TaxonRank
          attribute? :kingdom, Types::String
          attribute? :phylum, Types::String
          attribute? :class, Types::String
          attribute? :order, Types::String
          attribute? :family, Types::String
          attribute? :genus, Types::String
          attribute? :vernacularNames, Types::Hash
        end
      end
    end
  end
end
