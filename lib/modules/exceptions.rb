module Exceptions
  public
  class FileCorruptError < IOError; end
  class FileEmptyError < IOError; end
  class FileNotFoundError < IOError; end
  class FileAlreadyExistsError < IOError; end
  class NotAnAudioFileError < IOError; end
  class NotAnImageFileError < IOError; end
  class AudioFileNotFoundError < FileNotFoundError; end
  class SpectrogramFileNotFoundError < FileNotFoundError; end
  class AudioToolError < StandardError; end
  class AudioToolTimedOutError < AudioToolError; end
  class InvalidSampleRateError < ArgumentError; end
  class SegmentRequestTooLong < ArgumentError; end
  class SegmentRequestTooShort < ArgumentError; end
  class HarvesterError < StandardError; end
  class HarvesterConfigurationError < HarvesterError; end
  class HarvesterConfigFileNotFound < HarvesterConfigurationError; end
  class HarvesterIOError < HarvesterError; end
  class HarvesterEndpointError < HarvesterError; end
  class HarvesterCommunicationError < HarvesterEndpointError; end
  class HarvesterAnalysisError < HarvesterError; end
end