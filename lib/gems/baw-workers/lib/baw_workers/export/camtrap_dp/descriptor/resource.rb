# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        # implements: camtrap-dp-profile-acoustic.json#/allOf/1/properties/resources/items/oneOf/0
        class Resource < Descriptor
          attribute :name, Types::String
          attribute :path, Types::UrlOrPath

          # The resources in camtrap-dp are tabular-data-resources, so this is a fixed value.
          attribute :profile, Types::String.default('tabular-data-resource')
          attribute :format, Types::String.default('csv')
          attribute :mediatype, Types::String.default('text/csv')
          attribute :encoding, Types::String.default('utf-8')

          # The raw parsed JSON table schema or url-or-path to the schema
          attribute :schema, Types::Schema
        end
      end
    end
  end
end
