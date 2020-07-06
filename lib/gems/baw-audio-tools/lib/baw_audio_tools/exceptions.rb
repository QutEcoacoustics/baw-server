# frozen_string_literal: true

module BawAudioTools
  module Exceptions
    class FileCorruptError < IOError; end
    class FileEmptyError < IOError; end
    class FileNotFoundError < IOError; end
    class FileAlreadyExistsError < IOError; end
    class FileTooSmallError < IOError; end
    class NotAnAudioFileError < IOError; end
    class NotAnImageFileError < IOError; end
    class AudioFileNotFoundError < FileNotFoundError; end
    class SpectrogramFileNotFoundError < FileNotFoundError; end
    class AudioToolError < StandardError; end
    class AudioToolTimedOutError < AudioToolError; end
    class InvalidSampleRateError < ArgumentError; end
    class SegmentRequestTooLong < ArgumentError; end
    class SegmentRequestTooShort < ArgumentError; end
    class CacheRequestError < ArgumentError; end
    class InvalidTargetMediaTypeError < ArgumentError; end
    class FileContentExtMismatchError < StandardError; end
  end
end
