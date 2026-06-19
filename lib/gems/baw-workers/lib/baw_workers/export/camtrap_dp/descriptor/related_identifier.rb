# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
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
