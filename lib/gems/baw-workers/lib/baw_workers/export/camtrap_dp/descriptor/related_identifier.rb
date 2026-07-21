# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/relatedIdentifiers/items
        class RelatedIdentifier < Descriptor
          attribute :relationType, Types::String
          attribute :relatedIdentifier, Types::String
          attribute :relatedIdentifierType, Types::String
          attribute? :resourceTypeGeneral, Types::String.optional
        end
      end
    end
  end
end
