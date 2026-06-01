# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      module Descriptor
        # Represents a source of the package, e.g. a data source. Can be a data management platform from which the
        # package was derived.
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/sources/items
        class Source < Base
          attribute? :title, Types::String
          attribute? :path, Types::UrlOrPath
          attribute? :email, Types::String
          attribute? :version, Types::String
        end
      end
    end
  end
end
