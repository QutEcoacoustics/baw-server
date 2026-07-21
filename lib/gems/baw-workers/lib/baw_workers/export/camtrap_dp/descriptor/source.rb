# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        # Represents a source of the package, e.g. a data source. Can be a data management platform from which the
        # package was derived.
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/sources/items
        class Source < Descriptor
          attribute? :title, Types::String.optional
          attribute? :path, Types::UrlOrPath.optional
          attribute? :email, Types::String.optional
          attribute? :version, Types::String.optional
        end
      end
    end
  end
end
