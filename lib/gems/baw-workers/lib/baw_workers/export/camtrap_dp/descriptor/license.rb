# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        class License < Descriptor
          attribute :name, Types::String
          attribute? :path, Types::String.optional
          attribute? :title, Types::String.optional
          attribute :scope, Types::String.enum('data', 'media')
        end
      end
    end
  end
end
