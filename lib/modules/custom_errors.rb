module CustomErrors
  public
  class RoutingArgumentError < ArgumentError; end
  class ItemNotFoundError < ActiveResource::ResourceNotFound
    attr_reader :message
  end
  class UnsupportedMediaTypeError < ActiveResource::BadRequest
    attr_reader :message
  end
  class UnprocessableEntityError < ActiveResource::BadRequest
    attr_reader :message
  end
end