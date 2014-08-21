module Api
  # Builds api responses.
  class Response

    # Get the status code for a status symbol.
    # @param [Symbol] status_symbol
    # @return [Fixnum] status code
    def status_code(status_symbol = :ok)
      Rack::Utils::SYMBOL_TO_STATUS_CODE[status_symbol]
    end

    # Get the status symbol for a status code.
    # @param [Fixnum] status_code
    # @return [Symbol] status symbol
    def status_symbol(status_code = 200)
      Rack::Utils::SYMBOL_TO_STATUS_CODE.invert[status_code]
    end

    # Get the status phrase for a status symbol.
    # @param [Symbol] status_symbol
    # @return [String] status phrase
    def status_phrase(status_symbol = :ok)
      Rack::Utils::HTTP_STATUS_CODES[status_code(status_symbol)]
    end

    # Create the basic structure for an api response.
    # @param [Symbol] status_symbol
    # @return [Hash] response
    def response_base(status_symbol = :ok)
      {
          meta: {
              status: status_code(status_symbol),
              message: status_phrase(status_symbol)
          },
          data: nil
      }
    end

    # Create a data api response.
    # @param [Symbol] status_symbol
    # @param [Hash, Array, Object] data
    # @return [Hash] response
    def response_data(status_symbol = :ok, data = {})
      json_response = response_base(status_symbol)
      json_response[:data] = data
      json_response
    end

    # Create an error api response.
    # @param [Symbol] status_symbol
    # @param [String] message
    # @param [Hash] links_object
    # @return [Hash] response
    def response_error(status_symbol, message, links_object = nil)
      response_data = response_base(status_symbol)

      response_data[:meta][:error] = {} if !message.blank? || !links_object.blank?

      response_data[:meta][:error][:details] = message unless message.blank?

      response_data[:meta][:error][:links] = {} unless links_object.blank?
      response_data[:meta][:error][:links]['sign in'] = url_helper.new_user_session_url if !links_object.blank? && links_object.include?(:sign_in)
      response_data[:meta][:error][:links]['request permissions'] = url_helper.new_access_request_projects_url if !links_object.blank? && links_object.include?(:permissions)
      response_data[:meta][:error][:links]['confirm your account'] = url_helper.new_user_confirmation_url if !links_object.blank? && links_object.include?(:confirm)

      response_data
    end

    def response_paging(order_by, direction)
      {
          order_by: order_by,
          direction: direction
      }
    end

    def response_paging(offset, limit, controller, action)
      offset = 0 if offset < 0
      limit = 0 if offset < 0

      {
          offset: offset,
          limit: limit,
          next: url_helper.url_for(controller: controller, action: action, offset: offset),
          previous: url_helper.url_for(controller: controller, action: action, offset: offset)
      }
    end

    # Get param value if available, otherwise a default value.
    # @param [ActiveSupport::HashWithIndifferentAccess] request_params
    # @param [Hash] modified_params
    # @param [String] param_name
    # @param [Object] default_value
    def get_param_value(request_params, modified_params, param_name, default_value)
      if request_params.include?(param_name)
        param_value = request_params[param_name]
        modified_params[param_name] = param_value
      else
        param_value = default_value
      end
      param_value
    end

    private

    def url_helper
      UrlHelpers
    end

    def format_date_time(value)
      if value.respond_to?(:iso8601)
        value.iso8601(3) # 3 decimal places
      else
        value
      end
    end

    def to_f_or_i_or_s(v)
      # http://stackoverflow.com/questions/8071533/convert-input-value-to-integer-or-float-as-appropriate-using-ruby
      ((float = Float(v)) && (float % 1.0 == 0) ? float.to_i : float) rescue v
    end

  end
end