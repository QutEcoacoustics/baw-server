# frozen_string_literal: true

module Emu
  # Extract metadata from files
  module Metadata
    include SemanticLogger::Loggable

    module_function

    # Run `emu metadata` on a path
    # @param path [Pathname] the path to analyze
    # @return [ExecuteResult] The result from executing the emu command.
    def extract(path)
      raise ArgumentError, 'path must exist and be pathname' unless path.is_a?(Pathname) && path.exist?

      Emu.execute('metadata', path)
    end
  end
end
