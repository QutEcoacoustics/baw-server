module CustomErrors
  public
  class RoutingArgumentError < ArgumentError; end
  class ItemNotFoundError < StandardError; end
  class UnsupportedMediaTypeError < StandardError
    attr_reader :available_formats_info

    def initialize(available_formats_info)
      @available_formats_info = available_formats_info
    end
  end
  class UnprocessableEntityError < StandardError; end
end