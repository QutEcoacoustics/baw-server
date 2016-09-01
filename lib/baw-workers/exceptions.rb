module BawWorkers
  module Exceptions
    public
    class UnsupportedAudioFile < BawAudioTools::Exceptions::NotAnAudioFileError; end
    class HarvesterError < StandardError; end
    class HarvesterConfigurationError < HarvesterError; end
    class HarvesterConfigFileNotFound < HarvesterConfigurationError; end
    class HarvesterIOError < HarvesterError; end
    class HarvesterAudioToolError < HarvesterIOError; end
    class HarvesterEndpointError < HarvesterError; end
    class HarvesterAnalysisError < HarvesterError; end
    class AnalysisCacheError < StandardError; end
    class PartialPayloadMissing < StandardError; end
  end
end