module Api
  # Builds api responses.
  class Response
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

    # Create meta hash for an api response.
    # @param [Symbol] status_symbol
    # @return [Hash] meta hash
    def meta(status_symbol = :ok)
      {
          meta: {
              status: status_code(status_symbol),
              message: status_phrase(status_symbol)
          }
      }
    end

    # Create data hash for an api response.
    # @param [Hash, Array, Object] data
    # @return [Hash] response
    def data(data = nil)
      {
          data: data
      }
    end

    # Create error hash for an api response.
    # @param [String] message
    # @param [Hash] links_object
    # @return [Hash] error hash
    def error(message, links_object = nil)
      result = {}
      result[:error] = {} if !message.blank? || !links_object.blank?
      result[:error][:details] = message unless message.blank?
      result
    end

    # Create link hash for an api response.
    # @param [String] display_text
    # @param [String] link
    # @return [Hash] link hash
    def link_base(display_text, link)
      {display_text: display_text, link: link}
    end

    # Create links array for an api response.
    # @param [Hash] links_object
    # @return [Array] links array
    def error_links(links_object = nil)
      link_array = []
      add_error_link(link_array, links_object, :sign_in, error_link_sign_in)
      add_error_link(link_array, links_object, :permissions, error_link_new_permissions)
      add_error_link(link_array, links_object, :confirm, error_link_confirm_account)
      link_array
    end

    # Create sort hash for an api response.
    # @param [Symbol] order_by
    # @param [Symbol] direction
    # @return [Hash] sort hash
    def sort(order_by, direction)
      {
          sort: {
              order_by: order_by,
              direction: direction
          }
      }
    end

    # Create the basic structure for an api response.
    # @param [Symbol] status_symbol
    # @param [Hash, Array, Object] data
    # @return [Hash] response
    def base(status_symbol = :ok, data = nil)
      meta_hash = meta(status_symbol)
      data_hash = data(data)
      {}.merge(meta_hash).merge(data_hash)
    end

    # Create basic paging for an api response.
    # @param [Integer] page
    # @param [Integer] items
    # @return [Hash] paging hash
    def paging(page, items)
      {
          paging: {
              page: page,
              items: items
          }
      }
    end

    # Create paging counts for an api response.
    # @param [Integer] actual_items_count
    # @param [Integer] total
    # @return [Hash] paging hash
    def paging_counts(actual_items_count, total)
      {
          paging: {
              count: actual_items_count,
              total: total
          }
      }
    end

    # Create paging link for an api response.
    # @param [Symbol] controller
    # @param [Symbol] action
    # @param [Integer] page
    # @param [Integer] items
    # @param [String] filter_text
    # @param [Hash] filter_generic_keys
    # @return [string] paging link
    def paging_link(controller, action, page = nil, items = nil, filter_text = nil, filter_generic_keys = {})
      additional_info = {}
      additional_info[:controller] = controller unless controller.blank?
      additional_info[:action] = action unless action.blank?
      additional_info[:page] = page unless page.blank?
      additional_info[:items] = items unless items.blank?
      additional_info[:filter_partial_match] = filter_text unless filter_text.blank?
      unless filter_generic_keys.blank?
        filter_generic_keys.each do |key, value|
          additional_info[key] = value
        end
      end

      url_helpers.url_for(additional_info)
    end

    def response_error(status_symbol, detail_message, links_object = nil)
      meta_info = meta(status_symbol)
      error_info = error(detail_message, links_object)
      data_info = data(nil)

      result = data_info.merge(meta_info)
      result[:meta].merge!(error_info)
      result
    end

    # Create filter for an api response.
    # @param [Hash] params
    # @param [ActiveRecord::Base] model
    # @param [Hash] filter_settings
    # @return [Hash] api response
    def response_filter(params, model, filter_settings)
      filter_query = Filter::Query.new(params, model, filter_settings)

      # query without paging to get total
      query = filter_query.query_without_paging

      # metadata
      meta_info = meta(:ok)

      # paging
      if filter_query.has_paging_params?
        paging_info, query = response_paging(
            filter_query,
            query,
            filter_settings.controller,
            filter_settings.action)
        meta_info.merge!(paging_info)
      end

      # sort
      if filter_query.has_sort_params?
        sort_info = sort(
            filter_query.sort.order_by,
            filter_query.sort.direction)
        query = filter_query.query_sort(query)
        meta_info.merge!(sort_info)
      end

      # execute query to get entire page of info
      # after adding paging and sort
      data_info = data(query.all)

      # result
      {}.merge(meta_info).merge(data_info)
    end

    private

    # Create paging hash for an api response.
    # @param [Filter::Query] filter_query
    # @param [ActiveRecord::Relation] query
    # @param [Symbol] controller
    # @param [Symbol] action
    # @return [Hash] paging hash
    def response_paging(filter_query, query, controller, action)
      # execute a count against entire set without paging
      total = query.count

      # add paging
      query = filter_query.query_paging(query)

      # execute a count for this page only
      count = query.count

      paging = filter_query.paging

      paging_info = paging(paging.page, paging.items)
      paging_count_info = paging_counts(count, total)
      paging_link_current = paging_link(
          controller, action,
          paging.page, paging.items,
          filter_query.qsp_text_filter,
          filter_query.qsp_generic_filters
      )

      max_page = restrict_to_bounds((total % paging.items))

      prev_page = restrict_to_bounds(paging.page - 1, 1, max_page)
      next_page = restrict_to_bounds(paging.page + 1, 1, max_page)

      paging_link_prev = paging_link(
          controller, action,
          prev_page,
          paging.items,
          filter_query.qsp_text_filter,
          filter_query.qsp_generic_filters
      )
      paging_link_next = paging_link(
          controller, action,
          next_page,
          paging.items,
          filter_query.qsp_text_filter,
          filter_query.qsp_generic_filters
      )


      [
          {
              paging: {
                  links: {
                      previous: link_base('previous', paging_link_prev),
                      next: link_base('next', paging_link_next)
                  }
              }
          },
          query
      ]
    end

    def restrict_to_bounds(value, lower = 1, upper = nil)
      value_i = value.to_i

      value_i = lower if !lower.blank? && value_i < lower
      value_i = upper if !upper.blank? && value_i > upper
      value_i
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

    def add_error_link(link_array, links_object, key, value)
      unless links_object.blank?
        if links_object.include?(key)
          link_array.push(value)
        end
      end
      link_array
    end

    # Create sign in link hash.
    # @return [Hash] link hash
    def error_link_sign_in
      link_base('sign in', url_helpers.new_user_session_path)
    end

    # Create permissions link hash.
    # @return [Hash] link hash
    def error_link_new_permissions
      link_base('request permissions', url_helpers.new_access_request_projects_path)
    end

    # Create confirm account link hash.
    # @return [Hash] link hash
    def error_link_confirm_account
      link_base('confirm your account', url_helpers.new_user_confirmation_path)
    end

  end
end