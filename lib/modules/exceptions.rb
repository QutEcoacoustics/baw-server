module Exceptions
  class AudioFileNotFoundError < IOError; end
  class SpectrogramFileNotFoundError < IOError; end
  class HarvesterError < StandardError; end
  class HarvesterConfigFileNotFound < HarvesterError; end
  class HarvesterConfigurationError < HarvesterError; end
  class HarvesterIOError < HarvesterError; end
  class HarvesterEndpointError < HarvesterError; end
  class HarvesterAnalysisError < HarvesterError; end
end