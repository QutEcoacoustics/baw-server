module CustomErrors
  public
  class RoutingArgumentError < ArgumentError; end
  class ItemNotFoundError < StandardError; end
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
  class UnprocessableEntityError < StandardError; end
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
end