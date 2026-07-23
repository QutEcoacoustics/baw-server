# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      module Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/relatedIdentifiers/items
        class RelatedIdentifier < Base
          attribute :relationType, Types::String
          attribute :relatedIdentifier, Types::String
          attribute :relatedIdentifierType, Types::String
          attribute? :resourceTypeGeneral, Types::String
        end
      end
    end
  end
end
