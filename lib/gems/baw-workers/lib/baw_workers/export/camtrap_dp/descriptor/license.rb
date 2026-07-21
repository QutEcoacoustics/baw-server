# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/licenses/items
        class License < Descriptor
          attribute :name, Types::String
          # TODO: required name AND/OR path, how to do that.
          attribute? :path, Types::UrlOrPath.optional
          attribute? :title, Types::String.optional
          attribute :scope, Types::String.enum('data', 'media')
        end
      end
    end
  end
end
