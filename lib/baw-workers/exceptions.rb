module BawWorkers
  module Exceptions
    public
    class HarvesterError < StandardError; end
    class HarvesterConfigurationError < HarvesterError; end
    class HarvesterConfigFileNotFound < HarvesterConfigurationError; end
    class HarvesterIOError < HarvesterError; end
    class HarvesterAudioToolError < HarvesterIOError; end
    class HarvesterEndpointError < HarvesterError; end
    class HarvesterAnalysisError < HarvesterError; end
  end
end