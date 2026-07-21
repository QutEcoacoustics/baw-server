# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/taxonomic
        class Taxonomic < Descriptor
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
      end
    end
  end
end
