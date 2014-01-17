module Exceptions
  public
  class FileCorruptError < IOError; end
  class FileEmptyError < IOError; end
  class FileNotFoundError < IOError; end
  class FileAlreadyExistsError < IOError; end
  class AudioFileNotFoundError < FileNotFoundError; end
  class SpectrogramFileNotFoundError < FileNotFoundError; end
  class AudioToolError < StandardError; end
  class HarvesterError < StandardError; end
  class HarvesterConfigFileNotFound < HarvesterError; end
  class HarvesterConfigurationError < HarvesterError; end
  class HarvesterIOError < HarvesterError; end
  class HarvesterEndpointError < HarvesterError; end
  class HarvesterAnalysisError < HarvesterError; end
end