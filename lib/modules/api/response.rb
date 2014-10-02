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

    # Build an api response hash.
    # @param [Symbol] status_symbol Response status.
    # @param [Object] data Data for response.
    # @param [Hash] opts the options for additional information.
    # @option opts [Hash] :filter (nil) Filter that produced data.
    # @option opts [Hash] :projection (nil) Projection.
    # @option opts [Array<Symbol>] :error_links ([]) Error links.
    # @option opts [String] :error_details (nil) Error details.
    # @option opts [Symbol] :order_by (nil) Model property data is ordered by.
    # @option opts [Symbol] :direction (nil) Direction of sort.
    # @option opts [Symbol] :controller (nil) Controller for paging links.
    # @option opts [Symbol] :action (nil) Action for paging links.
    # @option opts [Integer] :page (nil) Page number when paging.
    # @option opts [Integer] :items (nil) Number of items per page when paging.
    # @option opts [Integer] :count (nil) Actual number of items on a page when paging.
    # @option opts [Integer] :total (nil) Total items matching.
    # @option opts [String] :filter_text (nil) Text for contains filter.
    # @option opts [Hash] :filter_generic_keys ({}) Property/value pairs for equality filter.
    def build(status_symbol = :ok, data = nil, opts = {})
      # initialise with defaults
      opts.reverse_merge!(
          {
              error_links: [], error_details: nil,
              order_by: nil, direction: nil,
              page: nil, items: nil, count: nil, total: nil,
              filter_text: nil, filter_generic_keys: {}
          })

      # base hash
      result = {
          meta: {
              status: status_code(status_symbol),
              message: status_phrase(status_symbol)
          },
          data: data
      }

      # include projection/filter if given
      unless opts[:projection].blank?
        result[:meta][:projection] = opts[:projection]
      end

      unless opts[:filter].blank?
        result[:meta][:filter] = opts[:filter]
      end

      # error information
      if !opts[:error_details].blank? || !opts[:error_links].blank?
        result[:meta][:error] = response_error(opts[:error_details], opts[:error_links])
      end

      # sort info
      if !opts[:order_by].blank? && !opts[:direction].blank?
        result[:meta][:sorting] = {
            order_by: opts[:order_by],
            direction: opts[:direction]
        }
      end

      # paging: page, items
      if !opts[:page].blank? && !opts[:items].blank?
        result[:meta][:paging] = {
            page: opts[:page],
            items: opts[:items]
        }
      end

      # paging: count, total
      if !opts[:count].blank? && !opts[:total].blank?
        result[:meta][:paging] = {} unless result[:meta].include?(:paging)
        result[:meta][:paging][:count] = opts[:count]
        result[:meta][:paging][:total] = opts[:total]
      end

      # max page
      max_page = nil
      if !opts[:total].blank? && !opts[:items].blank?
        max_page = result[:meta][:paging][:max_page] = (opts[:total].to_f / opts[:items].to_f).ceil
      end

      # paging: next/prev links
      if result[:meta].include?(:paging)
        controller = opts[:controller]
        action = opts[:action]

        current_link = paging_link(
            controller, action,
            opts[:page], opts[:items],
            opts[:filter_text], opts[:filter_generic_keys])

        previous_link = paging_link(
            controller, action,
            restrict_to_bounds(opts[:page] - 1),
            opts[:items],
            opts[:filter_text],
            opts[:filter_generic_keys]
        )
        next_link = paging_link(
            controller, action,
            restrict_to_bounds(opts[:page] + 1, 1, max_page),
            opts[:items],
            opts[:filter_text],
            opts[:filter_generic_keys]
        )

        result[:meta][:paging][:current] = current_link
        result[:meta][:paging][:previous] = previous_link == current_link ? nil : previous_link
        result[:meta][:paging][:next] = next_link == current_link ? nil : next_link

      end

      result
    end

    def response_error(details, link_ids)
      error_hash = {}
      error_hash[:details] = details unless details.blank?
      error_hash[:links] = response_error_links(link_ids) unless link_ids.blank?
      error_hash
    end

    def response_error_links(link_ids)
      result = {}
      unless link_ids.blank?
        error_links = error_links_hash
        link_ids.each do |id|
          link_info = error_links[id]
          result[link_info.text] = link_info.url
        end
      end
      result
    end

    # Create and execute a query based on am index request.
    # @param [Hash] params
    # @param [ActiveRecord::Relation] query
    # @param [ActiveRecord::Base] model
    # @param [Hash] filter_settings
    # @return [ActiveRecord::Relation] query
    def response_index(params, query, model, filter_settings)
      filter_query = Filter::Query.new(params, query, model, filter_settings)

      # query without paging to get total
      new_query = filter_query.query_without_filter_paging_sorting

      add_paging_and_sorting(new_query, filter_settings, filter_query)
    end

    # Create and execute a query based on a filter request.
    # @param [Hash] params
    # @param [ActiveRecord::Relation] query
    # @param [ActiveRecord::Base] model
    # @param [Hash] filter_settings
    # @param [Symbol] status_symbol Response status.
    # @return [Hash] api response
    def response_filter(params, query, model, filter_settings, status_symbol = :ok)
      filter_query = Filter::Query.new(params, query, model, filter_settings)

      # query without paging to get total
      new_query = filter_query.query_without_paging_sorting

      paged_sorted_query, opts = add_paging_and_sorting(new_query, filter_settings, filter_query)

      # build response data
      data = paged_sorted_query.all

      # build complete api response
      opts[:filter] = filter_query.filter unless filter_query.filter.blank?
      opts[:projection] = filter_query.projection unless filter_query.projection.blank?
      result = build(status_symbol, data, opts)

      # return result
      result
    end

    private

    def add_paging_and_sorting(new_query, filter_settings, filter_query)
      # basic options
      opts = {
          controller: filter_settings.controller,
          action: filter_settings.action,
          filter_text: filter_query.qsp_text_filter,
          filter_generic_keys: filter_query.qsp_generic_filters
      }

      # paging
      if filter_query.has_paging_params?

        # execute a count against entire set without paging
        total = new_query.count

        # add paging
        new_query = filter_query.query_paging(new_query)

        # execute a count for this page only
        count = new_query.count

        # update options
        opts.merge!(
            page: filter_query.paging.page,
            items: filter_query.paging.items,
            count: count,
            total: total
        )
      end

      # sort
      if filter_query.has_sort_params?

        # add sorting
        new_query = filter_query.query_sort(new_query)

        # update options
        opts.merge!(
            order_by: filter_query.sorting.order_by,
            direction: filter_query.sorting.direction
        )
      end

      # return the constructed query and options
      [new_query, opts]
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

    # Get error links hash.
    # @return [Hash] links hash
    def error_links_hash
      {
          sign_in: {
              text: 'sign in',
              url: url_helpers.new_user_session_path
          },
          sign_up: {
              text: 'sign up',
              url: url_helpers.new_user_registration_path
          },
          permissions: {
              text: 'request permissions',
              url: url_helpers.new_access_request_projects_path
          },
          confirm: {
              text: 'confirm your account',
              url: url_helpers.new_user_confirmation_path
          }
      }
    end

  end
end