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

    # Add custom fields to an item.
    # @param [Object] item A single item from the response.
    # @param [Object] user current_user
    # @param [Hash] opts the options for additional information.
    # @return [Hash] prepared item
    def prepare(item, user, opts = {})
      fail CustomErrors::FilterArgumentError, "Item must be an ActiveRecord::Base, got #{item.class}" unless item.is_a?(ActiveRecord::Base)

      filter_settings = item.class.filter_settings
      item_new = item

      # add new spec fields if filter_settings specifies a lambda for new_spec_fields
      new_spec_fields = filter_settings[:new_spec_fields]
      new_spec_fields_is_lambda = !new_spec_fields.blank? && new_spec_fields.lambda?
      new_spec_fields_hash = {}
      if new_spec_fields_is_lambda && (item_new.nil? || item_new.id.nil?)
        new_spec_fields_hash = new_spec_fields.call(user)
      end

      # add custom fields if filter_settings specifies a lambda for custom_fields
      custom_fields = filter_settings[:custom_fields]
      custom_fields_is_lambda = !custom_fields.blank? && custom_fields.lambda?
      custom_fields_hash = {}
      if custom_fields_is_lambda && !item_new.nil? && !item_new.id.nil?
        item_new, custom_fields_hash = custom_fields.call(item, user)
      end

      # project using filter projection (already in query for items) or default fields
      has_projection = opts[:projection]
      item_new = {} if item_new.nil?
      if has_projection
        base_json = item_new.as_json
      else
        default_fields = filter_settings[:render_fields]
        base_json = item_new.as_json(only: default_fields)
      end

      base_json.merge(new_spec_fields_hash).merge(custom_fields_hash)
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
    # @option opts [Integer] :total (nil) Total items matching.
    # @option opts [String] :filter_text (nil) Text for contains filter.
    # @option opts [Hash] :filter_generic_keys ({}) Property/value pairs for equality filter.
    # @return [Hash] data
    def build(status_symbol = :ok, data = nil, opts = {})
      # initialise with defaults
      opts.reverse_merge!(
          {
              error_links: [], error_details: nil, error_info: nil,
              order_by: nil, direction: nil,
              page: nil, items: nil, total: nil,
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
      if !opts[:error_details].blank? || !opts[:error_links].blank? || !opts[:error_info].blank?
        result[:meta][:error] = response_error(opts)
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
      unless opts[:total].blank?
        result[:meta][:paging] = {} unless result[:meta].include?(:paging)
        result[:meta][:paging][:total] = opts[:total]
      end

      # paging: max page
      if !opts[:total].blank? && !opts[:items].blank?
        max_page = (opts[:total].to_f / opts[:items].to_f).ceil
        opts[:max_page] = max_page
        result[:meta][:paging][:max_page] = max_page
      end

      # paging: next/prev links
      if result[:meta].include?(:paging)
        current_link = paging_link(opts, 0)
        previous_link = paging_link(opts, -1)
        next_link = paging_link(opts, 1)

        result[:meta][:paging][:current] = current_link
        result[:meta][:paging][:previous] = previous_link == current_link ? nil : previous_link
        result[:meta][:paging][:next] = next_link == current_link ? nil : next_link

      end

      result
    end

    def response_error(opts)
      error_hash = {}
      error_hash[:details] = opts[:error_details] unless opts[:error_details].blank? # string
      error_hash[:links] = response_error_links(opts[:error_links]) unless opts[:error_links].blank? # array
      error_hash[:info] = opts[:error_info] unless [:error_info].blank? # hash or string or array
      error_hash
    end

    def response_error_links(link_ids)
      result = {}
      unless link_ids.blank?
        error_links = error_links_hash
        link_ids.each do |id|
          link_info = error_links[id]
          result[link_info[:text]] = link_info[:url]
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
    def response_advanced(params, query, model, filter_settings)
      response(params, query, model, filter_settings)
    end

    # Get error links hash.
    # @return [Hash] links hash
    def error_links_hash
      {
          sign_in: {
              text: I18n.t('devise.sessions.new.sign_in'),
              url: url_helpers.new_user_session_path
          },
          sign_up: {
              text: I18n.t('devise.registrations.new.sign_up'),
              url: url_helpers.new_user_registration_path
          },
          permissions: {
              text: I18n.t('models.permissions.request_permissions'),
              url: url_helpers.new_access_request_projects_path
          },
          confirm: {
              text: I18n.t('devise.shared.links.confirm_account'),
              url: url_helpers.new_user_confirmation_path
          },
          reset_password: {
              text: I18n.t('devise.shared.links.reset_password'),
              url: url_helpers.new_user_password_path
          },
          resend_unlock: {
              text: I18n.t('devise.shared.links.unlock_account'),
              url: url_helpers.new_user_unlock_path
          }
      }
    end

    private

    # Create and execute a query based on a filter request.
    # @param [Hash] params
    # @param [ActiveRecord::Relation] query
    # @param [ActiveRecord::Base] model
    # @param [Hash] filter_settings
    # @return [Array] query, options
    def response(params, query, model, filter_settings)
      filter_query = Filter::Query.new(params, query, model, filter_settings)

      # query without paging to get total
      new_query = filter_query.query_without_paging_sorting

      paged_sorted_query, opts = add_paging_and_sorting(new_query, filter_settings, filter_query)


      # build complete api response
      opts[:filter] = filter_query.filter unless filter_query.filter.blank?
      opts[:projection] = filter_query.projection unless filter_query.projection.blank?
      opts[:additional_params] = filter_query.parameters.except(
          model.to_s.underscore.to_sym,
          :filter, :projection,
          :action, :controller,
          :format, :paging, :sorting)

      [paged_sorted_query, opts]
    end

    def add_paging_and_sorting(new_query, filter_settings, filter_query)
      # basic options

      param_controller = filter_query.parameters[:controller]
      param_action = filter_query.parameters[:action]

      opts = {
          controller: param_controller.blank? ? filter_settings[:controller] : param_controller,
          action: param_action.blank? ? filter_settings[:action] : param_action,
          filter_text: filter_query.qsp_text_filter,
          filter_generic_keys: filter_query.qsp_generic_filters
      }

      # paging
      if filter_query.has_paging_params?

        # execute a count against entire set without paging
        total = new_query.size

        # add paging
        new_query = filter_query.query_paging(new_query)
        items = filter_query.is_paging_disabled? ? total : filter_query.paging[:items]

        # update options
        opts.merge!(
            page: filter_query.paging[:page],
            items: items,
            total: total
        )
      end

      # sort
      if filter_query.has_sort_params?

        # add sorting
        new_query = filter_query.query_sort(new_query)

        # update options
        opts.merge!(
            order_by: filter_query.sorting[:order_by],
            direction: filter_query.sorting[:direction]
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

    # @param [Hash] opts the options for additional information.
    # @option opts [Symbol] :controller (nil) Controller for paging links.
    # @option opts [Symbol] :action (nil) Action for paging links.
    # @option opts [Integer] :page (nil) Page number when paging.
    # @option opts [Integer] :items (nil) Number of items per page when paging.
    # @option opts [String] :filter_text (nil) Text for contains filter.
    # @option opts [Hash] :filter_generic_keys ({}) Property/value pairs for equality filter.
    # @option opts [Hash] :additional_params ({}) Additional property/value pairs.
    # @param [Integer] page_offset
    def paging_link(opts, page_offset)

      controller = opts[:controller]
      action = opts[:action]

      page = opts[:page]
      items = opts[:items]
      max_page = opts[:max_page]
      page = restrict_to_bounds(opts[:page] + page_offset, 1, max_page)

      disable_paging = opts[:disable_paging]

      filter_text = opts[:filter_text]
      filter_generic_keys = opts[:filter_generic_keys]
      additional_params = opts[:additional_params]

      order_by = opts[:order_by]
      direction = opts[:direction]

      link_params = {}
      link_params[:controller] = controller unless controller.blank?
      link_params[:action] = action unless action.blank?
      link_params[:page] = page unless page.blank?
      link_params[:items] = items unless items.blank?
      link_params[:disable_paging] = disable_paging unless disable_paging.blank?
      link_params[:filter_partial_match] = filter_text unless filter_text.blank?
      link_params[:order_by] = order_by unless order_by.blank?
      link_params[:direction] = direction unless direction.blank?
      link_params.merge!(additional_params) unless additional_params.blank?

      unless filter_generic_keys.blank?
        filter_generic_keys.each do |key, value|
          link_params[('filter_' + key.to_s).to_sym] = value
        end
      end

      url_helpers.url_for(link_params)
    end

  end
end