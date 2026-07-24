# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      module Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/contributors/items
        class Contributor < Base
          # name/title of the person or organisation
          attribute :title, Types::String
          attribute :role, Types::Role

          attribute? :email, Types::String
          attribute? :path, Types::Url
          attribute? :organization, Types::String
        end
      end
    end
  end
end
