# frozen_string_literal: true

module CustomErrors
  class RoutingArgumentError < ArgumentError; end
  class ItemNotFoundError < StandardError; end
  class TooManyItemsFoundError < StandardError; end
  class AnalysisJobStartError < StandardError; end
  class OrphanedSiteError < StandardError; end
  class BadHeaderError < StandardError; end
  class RequestedMediaTypeError < StandardError
    attr_reader :available_formats_info

    def initialize(message = nil, available_formats_info = nil)
      @message = message
      @available_formats_info = available_formats_info
    end

    def to_s
      @message
    end
  end
  class NotAcceptableError < RequestedMediaTypeError; end
  class UnsupportedMediaTypeError < RequestedMediaTypeError; end
  class MethodNotAllowedError < StandardError
    attr_reader :additional_details

    def initialize(message = nil, except = [], available_methods = [:get, :post, :put, :patch, :head, :delete, :options])
      @message = message
      @available_methods = available_methods - except
    end

    attr_reader :available_methods

    def to_s
      @message
    end
  end
  class UnprocessableEntityError < StandardError
    attr_reader :additional_details

    def initialize(message = nil, additional_details = nil)
      @message = message
      @additional_details = additional_details
    end

    def to_s
      @message
    end
  end
  class BadRequestError < StandardError; end
  class FilterArgumentError < ArgumentError
    attr_reader :filter_segment

    def initialize(message = nil, filter_segment = nil)
      @message = message
      @filter_segment = filter_segment
    end

    def to_s
      @message
    end
  end
  class AudioGenerationError < RuntimeError
    attr_reader :job_info

    def initialize(message = nil, job_info = nil)
      @message = message
      @job_info = job_info
    end

    def to_s
      @message
    end
  end
end
