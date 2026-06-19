# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        class Source < Descriptor
          attribute? :title, Types::String.optional
          attribute? :path, Types::String.optional
          attribute? :email, Types::String.optional
          attribute? :version, Types::String.optional
        end
      end
    end
  end
end
