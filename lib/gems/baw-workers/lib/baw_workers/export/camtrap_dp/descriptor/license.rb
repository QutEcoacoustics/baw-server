# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      module Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/licenses/items
        class License < Base
          attribute :name, Types::String
          attribute? :path, Types::UrlOrPath
          attribute? :title, Types::String
          attribute :scope, Types::String.enum('data', 'media')
        end
      end
    end
  end
end
