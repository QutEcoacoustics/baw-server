module CustomErrors
  public
  class RoutingArgumentError < ArgumentError; end
  class ItemNotFoundError < StandardError; end
  class RequestedMediaTypeError < StandardError
    attr_reader :available_formats_info
    def initialize(available_formats_info)
      @available_formats_info = available_formats_info
    end
  end
  class NotAcceptableError < RequestedMediaTypeError; end
  class UnsupportedMediaTypeError < RequestedMediaTypeError; end
  class UnprocessableEntityError < StandardError; end
end