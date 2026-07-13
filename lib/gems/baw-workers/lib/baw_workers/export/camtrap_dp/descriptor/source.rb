# frozen_string_literal: true

module BawWorkers
  module Export
    module CamtrapDp
      class Descriptor
        # Represnts a source of the package, e.g. a data source. Can be a data management platform from which the
        # package was derived.
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
