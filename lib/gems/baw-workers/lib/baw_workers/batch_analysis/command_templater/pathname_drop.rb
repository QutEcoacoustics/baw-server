# frozen_string_literal: true

require 'liquid'

module BawWorkers
  module BatchAnalysis
    module CommandTemplater
      # Wraps Pathname values to provide string output in Liquid templates.
      class PathnameDrop < ::Liquid::Drop
        def initialize(path)
          super()
          @path = path
        end

        def to_s
          @path.to_s
        end

        def name
          @path.basename(@path.extname).to_s
        end

        def basename
          @path.basename.to_s
        end

        def extname
          @path.extname
        end

        def dirname
          @path.dirname.to_s
        end
      end
    end
  end
end
