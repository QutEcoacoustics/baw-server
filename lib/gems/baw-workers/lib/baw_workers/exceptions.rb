# frozen_string_literal: true

module BawWorkers
  # Named errors for communication. Mainly just wrap other standard errors.
  module Exceptions
    class UnsupportedAudioFile < BawAudioTools::Exceptions::NotAnAudioFileError; end

    class HarvesterError < StandardError; end

    class HarvesterConfigurationError < HarvesterError; end

    class HarvesterConfigFileNotFound < HarvesterConfigurationError; end

    class HarvesterIOError < HarvesterError; end

    class HarvesterAudioToolError < HarvesterIOError; end

    class HarvesterEndpointError < HarvesterError; end

    class HarvesterAnalysisError < HarvesterError; end

    class AnalysisCacheError < StandardError; end

    class AnalysisEndpointError < StandardError; end

    class ActionCancelledError < RuntimeError; end
  end
end
