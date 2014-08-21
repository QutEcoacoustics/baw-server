module Api
  # Builds api responses.
  class Response
    include Validate
    include UrlHelpers


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

    def paging_params
      params
    end

    def sort_params

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
      response_data[:meta][:error][:links]['sign in'] = url_helpers.new_user_session_url if !links_object.blank? && links_object.include?(:sign_in)
      response_data[:meta][:error][:links]['request permissions'] = url_helpers.new_access_request_projects_url if !links_object.blank? && links_object.include?(:permissions)
      response_data[:meta][:error][:links]['confirm your account'] = url_helpers.new_user_confirmation_url if !links_object.blank? && links_object.include?(:confirm)

      response_data
    end

    def response_sort(order_by, direction)
      {
          order_by: order_by,
          direction: direction
      }
    end

    def response_paging(offset, limit, count, total, controller, action)
      values = validate_paging(offset, limit, validate_max_items)

      page = (offset.to_i / limit.to_i) + 1

      {
          page: page,
          items: limit,
          count: count,
          total: total,
          # TODO: include text filter, generic filter, order_by, direction, offset, limit
          next: url_helpers.url_for(controller: controller, action: action, offset: offset, items: limit),
          previous: url_helpers.url_for(controller: controller, action: action, offset: offset, items: limit)
      }
    end

    def response_paging_external(page, items, count, total, controller, action)
      values = validate_paging_external(page, items, validate_max_items)
      response_paging(values.offset, values.limit, count, total, controller, action)
    end

    def response_filter(params, model, valid_fields, text_fields)
      filter_query = Api::FilterQuery.new(params, model, valid_fields, text_fields)

      # query without paging to get total
      query = filter_query.query_without_paging

      # execute a count against entire set without paging
      total = query.count

      # add paging
      query = filter_query.query_paging(query)

      # execute a count for this page only
      count = query.count

      # execute query to get entire page of info
      all_data = query.all
      built_response = response_data(:ok, all_data)

      # add sorting info
      sorting = filter_query.get_sort
      built_response[:sorting] = response_sort(sorting.order_by, sorting.direction)

      # add paging info
      paging = filter_query.get_paging
      built_response[:pagination] = response_paging(
          paging.offset, paging.limit,
          count, total,
          :audio_recordings, :filter
      )

      # return result
      built_response
    end

    private

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