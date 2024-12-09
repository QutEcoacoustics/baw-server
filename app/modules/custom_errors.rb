# frozen_string_literal: true

module CustomErrors
  # Some errors we need not to be handled bby our custom error code.
  # Want them to just raise all the way to the top and not even generate a proper
  # api response.
  # These should all be internal server errors.
  # Why?
  #  - one of our header verifiers runs after the action, after the render.
  #    When it fails we can't render again.
  class UnhandledError < StandardError; end

  class BadHeaderError < UnhandledError; end

  class NegativeContentLengthError < BadHeaderError
    def initialize(message = nil)
      message ||= 'Content-Length header is negative'
      super
    end
  end

  # Base class for custom errors.
  # `render_error` can use the attributed from this class to construct better
  # error responses.
  # @abstract
  class CustomError < StandardError
    # A freeform data field used to convey additional information about the error
    # @return [String,Array,Hash]
    attr_reader :info

    # A list of links to related resources.
    # Either a list of well-known link symbols (see `Settings.api_response.error_links_hash`),
    # or a list of hashed, each which should contain `text` and `url` keys.
    # @return [Array<Symbol>,Array<Hash<Symbol,String>>]
    attr_reader :links

    # @return [Symbol]
    attr_reader :status_code

    # A short common error message that is prepended to the message.
    # @return [String]
    attr_reader :prefix

    # Whether or not this error should trigger an exception notification.
    # @return [Boolean]
    attr_reader :should_notify_error

    def initialize(message)
      # this stops the message defaulting to the class name
      message ||= ''
      super
      @should_notify_error = false

      raise 'Do not use CustomError directly' if instance_of?(CustomError)
    end

    def message
      original_message = super
      prefix_blank  = prefix.blank?
      message_blank = original_message.blank?

      if prefix_blank && message_blank
        self.class.name
      elsif prefix_blank
        original_message
      elsif message_blank
        prefix
      else
        "#{prefix}: #{original_message}"
      end
    end

    def message_without_prefix
      method(:message).super_method.call
    end
  end

  # For dealing with custom routing logic
  # error handling for routes that take a combination of attributes
  class RoutingArgumentError < CustomError
    def initialize(message = nil)
      super
      @status_code = :not_found
      @prefix = 'Could not find the requested page'

      @info = {
        original_route: Current.path,
        original_http_method: Current.method
      }
    end
  end

  # Mainly used for dynamic routing scenarios (e.g. serving a directory)
  class ItemNotFoundError < CustomError
    def initialize(message = nil)
      super
      @status_code = :not_found
      @prefix = 'Could not find the requested item'
    end
  end

  # Returns a 410 Gone error which we use to indicate soft deletes
  class GoneError < CustomError
    def initialize(message = nil)
      super
      @status_code = :gone
      @prefix = 'The requested item is no longer available'
    end
  end

  class TooManyItemsFoundError < CustomError; end

  class AnalysisJobStartError < CustomError; end

  # 415 - Unsupported Media Type
  # they sent what we don't want
  # render json: {
  #   code: 415,
  #   phrase: 'Unsupported Media Type',
  #   message: 'Requested format is invalid. It must be one of available_formats.',
  #   available_formats: @available_formats
  # }, status: :unsupported_media_type
  class RequestedMediaTypeError < CustomError
    attr_reader :available_formats_info

    def initialize(message = nil, available_formats_info = nil)
      super(message)
      @status_code = :unsupported_media_type
      @prefix = 'The format of the request is not supported'
      @info = { available_formats: available_formats_info } if available_formats_info.present?
    end
  end

  # 406 - Not Acceptable
  # we can't send what they want
  class NotAcceptableError < RequestedMediaTypeError
    def initialize(message = nil, available_formats_info = nil)
      super
      @status_code = :not_acceptable
      @prefix = 'None of the acceptable response formats are available'
    end
  end

  class UnsupportedMediaTypeError < RequestedMediaTypeError; end

  # 405 - Method Not Allowed
  # We don't allow that verb, for that request
  class MethodNotAllowedError < CustomError
    attr_reader :additional_details, :available_methods

    def initialize(
      message = nil,
      except = [],
      available_methods = [:get, :post, :put, :patch, :head, :delete, :options]
    )
      super(message)
      @status_code = :method_not_allowed
      @prefix = 'The method is known by the server but not supported by the target resource'
      @available_methods = available_methods - except
      @info = { available_methods: @available_methods.map(&:to_s).map(&:upcase) }
    end
  end

  # 422 - we're unable to process the request
  # (but the request is otherwise valid)
  class UnprocessableEntityError < CustomError
    # @param message [String,nil]
    # @param info [Hash,nil] additional information about the error - sent in API response!
    def initialize(message = nil, info = nil)
      super(message)
      @status_code = :unprocessable_content
      @prefix = 'The request could not be understood'
      @info = info if info.present?
    end
  end

  # Used to support our Actions API spec
  # https://github.com/QutEcoacoustics/baw-server/wiki/API:-Actions
  class InvalidActionError < CustomError
    def initialize(message, actions)
      super(message)
      @status_code = :not_found
      @prefix = 'Invalid action'
      @info = { allowed_actions: actions.pluck(:text) }

      @links = actions
    end
  end

  class RequestedMediaDurationInvalid < UnprocessableEntityError; end

  # 400 Bad request
  class BadRequestError < CustomError
    def initialize(message = nil)
      super
      @status_code = :bad_request
      @prefix = 'The request was not valid'
    end
  end

  # 400 Bad request but specifically for the path part of a URI
  class IllegalPathError < BadRequestError
    def initialize(message = nil)
      super
      @prefix = 'The requested url contains illegal characters'
    end
  end

  # 400 Bad request but specifically for an orphaned site
  class OrphanedSiteError < BadRequestError; end

  # 400 Bad request but specifically for our filter API
  class FilterArgumentError < BadRequestError
    attr_reader :filter_segment

    def initialize(message = nil, filter_segment = nil)
      super(message)
      @filter_segment = filter_segment
      @prefix = 'Filter parameters were not valid'
      @info = filter_segment if filter_segment.present?
    end
  end

  class AudioGenerationError < RuntimeError
    attr_reader :job_info

    def initialize(message = nil, job_info = nil)
      super(message)
      @job_info = job_info
      @status_code = :internal_server_error
      @prefix = 'Audio generation failed'
      @info = job_info if job_info.present?
    end
  end
end
