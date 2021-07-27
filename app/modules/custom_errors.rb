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
      super(message)
      @available_formats_info = available_formats_info
    end
  end

  class NotAcceptableError < RequestedMediaTypeError; end

  class UnsupportedMediaTypeError < RequestedMediaTypeError; end

  class MethodNotAllowedError < StandardError
    attr_reader :additional_details, :available_methods

    def initialize(
      message = nil,
      except = [],
      available_methods = [:get, :post, :put, :patch, :head, :delete, :options]
    )
      super(message)
      @available_methods = available_methods - except
    end
  end

  class UnprocessableEntityError < StandardError
    attr_reader :additional_details

    def initialize(message = nil, additional_details = nil)
      super(message)
      @additional_details = additional_details
    end
  end

  class RequestedMediaDurationInvalid < UnprocessableEntityError; end

  class BadRequestError < StandardError; end

  class FilterArgumentError < ArgumentError
    attr_reader :filter_segment

    def initialize(message = nil, filter_segment = nil)
      super(message)
      @filter_segment = filter_segment
    end
  end

  class AudioGenerationError < RuntimeError
    attr_reader :job_info

    def initialize(message = nil, job_info = nil)
      super(message)
      @job_info = job_info
    end
  end
end
