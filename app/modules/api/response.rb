# frozen_string_literal: true

module Api
  # Builds api responses.
  class Response
    include UrlHelpers

    # Get the status code for a status symbol.
    # @param [Symbol] status_symbol
    # @return [Fixnum] status code
    def status_code(status_symbol = :ok)
      Rack::Utils.status_code(status_symbol)
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

    # Formats an item for a #new response.
    # @param [Object] item A single item from the response.
    # @param [Object] user current_user
    # @param [Hash] _opts the options for additional information.
    # @return [Hash] prepared item
    def prepare_new(item, user, _opts = {})
      unless item.is_a?(ActiveRecord::Base)
        raise CustomErrors::FilterArgumentError, "Item must be an ActiveRecord::Base, got #{item.class}"
      end

      filter_settings = item.class.filter_settings
      item_new = item

      # add new spec fields if filter_settings specifies a lambda for new_spec_fields
      new_spec_fields = filter_settings[:new_spec_fields]
      new_spec_fields_is_lambda = new_spec_fields.present? && new_spec_fields.lambda?
      new_spec_fields_hash = {}
      if new_spec_fields_is_lambda && (item_new.nil? || item_new.id.nil?)
        new_spec_fields_hash = new_spec_fields.call(user)
      end

      new_spec_fields_hash
    end

    # Add custom fields to an item.
    # @param [Object] item A single item from the response.
    # @param [Object] user current_user
    # @param [Hash] additional_data Additional data to be merged into the item.
    # @param [Hash] opts the options for additional information.
    # @return [Hash] prepared item
    def prepare(item, user, additional_data, opts = {})
      unless item.is_a?(ActiveRecord::Base)
        raise CustomErrors::FilterArgumentError, "Item must be an ActiveRecord::Base, got #{item.class}"
      end

      additional_data ||= {}
      unless additional_data.is_a?(Hash)
        raise CustomErrors::FilterArgumentError, "Additional data must be a Hash, got #{additional_data.class}"
      end

      additional_data.deep_transform_keys!(&:to_s)

      filter_settings = item.class.filter_settings
      item_new = item

      # add custom fields if filter_settings specifies a lambda for custom_fields
      custom_fields = filter_settings[:custom_fields]
      custom_fields_is_lambda = custom_fields.present? && custom_fields.lambda?
      custom_fields_hash = {}
      if custom_fields_is_lambda && !item_new.nil? && !item_new.id.nil?
        item_new, custom_fields_hash = custom_fields.call(item, user)
        custom_fields_hash.transform_keys!(&:to_s)
      end
      custom_fields_keys = custom_fields_hash.keys

      # get newer sort of custom fields, and keep only string keys and transforms
      custom_fields_hash2 = filter_settings
        .fetch(:custom_fields2, {})
        # for calculated fields, they may not have a transform function, so skip those
        # and just use the value returned from the database
        .reject { |_key, value| value[:transform].nil? }
        .transform_values { |value| value[:transform] }
        .transform_keys(&:to_s)

      hashed_item = {}.merge(
        item_new&.as_json,
        additional_data,
        custom_fields_hash,
        custom_fields_hash2
      )

      # project using filter projection or default fields
      # Note: most queries with a projection already only return required fields
      # but some don't... currently those using custom_filter_2
      projection = opts[:projection]
      if projection
        if projection[:include]
          # backwards compatible hack: custom fields always used to be included,
          # no matter the projection
          hashed_item.slice(*(projection[:include].map(&:to_s) + custom_fields_keys))
        else
          hashed_item.except(*projection[:exclude].map(&:to_s))
        end => hashed_item
      else
        default_fields = filter_settings[:render_fields] +
                         custom_fields_keys +
                         # rendered by default but not defined is filter settings
                         additional_data.keys
        hashed_item = hashed_item.slice(*default_fields.map(&:to_s))
      end

      # Now that the projection is applied, transform any remaining
      # custom values.
      # We don't want to do this earlier because calculating a custom field
      # before the projection could result in unneeded custom fields being
      # included which apart from being slow may also fail due to missing select
      # data
      hashed_item.transform_values { |value|
        next value unless value.is_a?(Proc)

        value.call(item)
      }
    end

    # Build an api response hash.
    # @param [Symbol] status_symbol Response status.
    # @param [Object] data Data for response.
    # @param [Hash] opts the options for additional information.
    # @option opts [Hash] :filter (nil) Filter that produced data.
    # @option opts [Hash] :projection (nil) Projection.
    # @option opts [Hash] :capabilities (nil) Capabilities build by add_capabilities!.
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
      # initialize with defaults
      opts.reverse_merge!(
        {
          error_links: [], error_details: nil, error_info: nil,
          order_by: nil, direction: nil,
          page: nil, items: nil, total: nil,
          filter_text: nil, filter_generic_keys: {},
          warning: nil
        }
      )

      # base hash
      result = {
        meta: {
          status: status_code(status_symbol),
          message: status_phrase(status_symbol)
        },
        data:
      }

      result[:meta][:warning] = opts[:warning] if opts[:warning].present?

      # include projection/filter if given
      result[:meta][:projection] = opts[:projection] if opts[:projection].present?

      result[:meta][:filter] = opts[:filter] if opts[:filter].present?

      # error information
      if opts[:error_details].present? || opts[:error_links].present? || opts[:error_info].present?
        result[:meta][:error] = response_error(opts)
      end

      # sort info
      if opts[:order_by].present? && opts[:direction].present?
        result[:meta][:sorting] = {
          order_by: opts[:order_by],
          direction: opts[:direction]
        }
      end

      # paging: page, items
      if opts[:page].present? && opts[:items].present?
        result[:meta][:paging] = {
          page: opts[:page],
          items: opts[:items]
        }
      end

      # paging: count, total
      if opts[:total].present?
        result[:meta][:paging] = {} unless result[:meta].include?(:paging)
        result[:meta][:paging][:total] = opts[:total]
      end

      # paging: max page
      if opts[:total].present? && opts[:items].present?
        items = opts[:items].to_f
        total = opts[:total].to_f
        # prevent divide by 0 error
        max_page = items.positive? ? (total / items).ceil : 1
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

      # render capabilities
      # TODO: optionally render capabilities based on request headers
      capabilities = opts.fetch(:capabilities, nil)
      result[:meta][:capabilities] = capabilities if capabilities.present?

      result
    end

    def response_error(opts)
      error_hash = {}
      error_hash[:details] = opts[:error_details] if opts[:error_details].present? # string
      error_hash[:links] = response_error_links(opts[:error_links]) if opts[:error_links].present? # array
      error_hash[:info] = opts[:error_info] if opts[:error_info].present? # hash or string or array
      error_hash
    end

    # @param [Symbol, Hash] link_ids either a symbol that corresponds to
    # predefined links or a hash with the keys :text and :url
    def response_error_links(link_ids)
      result = {}
      if link_ids.present?
        error_links = error_links_hash
        link_ids.each do |id|
          link_info = if id.is_a?(Symbol)
                        error_links[id]
                      else
                        id
                      end
          result[link_info[:text]] = link_info[:url]
        end
      end
      result
    end

    # Create and execute a query based on an index request.
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

    # Format the capabilities hash for the response. Mutates opts.
    # @param [Hash] opts the current response opts hash
    # @param [Class] klass the class of the current resource
    # @param [Nil,Array<ActiveRecord::Base>,ActiveRecord::Base] item an instance of the current resource
    # @return [Hash<Symbol,Hash>] mutated opts with capabilities
    def add_capabilities!(opts, klass, item = nil)
      raise ArgumentError, 'klass must be a class' unless klass.is_a?(Class)
      raise ArgumentError, 'opts must be a hash' unless opts.is_a?(Hash)

      filter_settings = klass&.try(:filter_settings)

      # check we can get filter settings and that capabilities are defined for this class
      unless filter_settings in {capabilities: Hash}
        opts[:capabilities] = nil
        return
      end

      capabilities = filter_settings[:capabilities]

      opts[:capabilities] = capabilities.transform_values { |capability|
        evaluate_capability(item, klass, capability)
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
      # extract safe params and ensure we're dealing with a HWIA
      params = params.to_h if params.is_a? ActionController::Parameters
      unless params.is_a? ActiveSupport::HashWithIndifferentAccess
        raise ArgumentError, 'params needs to be HashWithIndifferentAccess or an ActionController::Parameters'
      end

      filter_query = Filter::Query.new(params, query, model, filter_settings)

      # query without paging to get total
      new_query = filter_query.query_without_paging_sorting

      paged_sorted_query, opts = add_paging_and_sorting(new_query, filter_settings, filter_query)

      # build complete api response
      opts[:filter] = filter_query.filter if filter_query.filter.present?
      opts[:filter_without_defaults] = filter_query.supplied_filter if filter_query.supplied_filter.present?
      opts[:projection] = filter_query.projection if filter_query.projection.present?
      opts[:capabilities] = filter_query.capabilities if filter_query.capabilities.present?
      opts[:additional_params] = filter_query.parameters.except(
        model.to_s.underscore.to_sym,
        :filter, :projection,
        :action, :controller,
        :format, :paging, :sorting,
        :page, :items
      )

      [paged_sorted_query, opts]
    end

    def add_paging_and_sorting(new_query, filter_settings, filter_query)
      # basic options

      param_controller = filter_query.parameters[:controller]
      param_action = filter_query.parameters[:action]

      opts = {
        controller: param_controller.presence || filter_settings[:controller],
        action: param_action.presence || filter_settings[:action],
        filter_text: filter_query.qsp_text_filter,
        filter_generic_keys: filter_query.qsp_generic_filters
      }

      # paging
      if filter_query.has_paging_params?

        # execute a count against entire set without paging
        total = new_query.size

        # if new_query involves aggregation, size returns the size of each group as a hash,
        # and what we need is the number of groups, so check if it is a hash and if so
        # use its length for the value of total.
        total = total.length if total.is_a? Hash

        # add paging
        new_query = filter_query.query_paging(new_query)
        items = filter_query.is_paging_disabled? ? total : filter_query.paging[:items]

        # update options
        opts.merge!(
          page: filter_query.paging[:page],
          items:,
          total:
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

    # if lower is higher than upper, lower will have priority
    def restrict_to_bounds(value, lower = 1, upper = nil)
      value_i = value.to_i

      value_i = upper if upper.present? && value_i > upper
      value_i = lower if lower.present? && value_i < lower

      value_i
    end

    def format_date_time(value)
      if value.respond_to?(:iso8601)
        value.iso8601(3) # 3 decimal places
      else
        value
      end
    end

    # Determines the capability either for a list of items
    # or for specific item.
    # When determining for a list of items, the item parameter should be nil.
    # @param [Nil,ActiveRecord::Base] item
    # @param [Class] klass
    # @param [Hash] capability
    # @return [Hash]
    def evaluate_capability(item, klass, capability)
      if item.nil?
        capability[:can_list]&.call(item)
      else
        capability[:can_item]&.call(item)
      end => can

      details = capability[:details]&.call(can, item, klass)

      { can:, details: }
    end

    def to_f_or_i_or_s(v)
      # http://stackoverflow.com/questions/8071533/convert-input-value-to-integer-or-float-as-appropriate-using-ruby

      ((float = Float(v)) && (float % 1.0).zero? ? float.to_i : float)
    rescue StandardError
      v
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

      opts[:page]
      items = opts[:items]
      max_page = opts[:max_page]
      page = restrict_to_bounds(opts[:page] + page_offset, 1, max_page)

      disable_paging = opts[:disable_paging]

      filter_text = opts[:filter_text]
      filter_generic_keys = opts[:filter_generic_keys]
      additional_params = opts[:additional_params]

      # special case :with_archived
      # we really don't want to

      order_by = opts[:order_by]
      direction = opts[:direction]

      link_params = {}
      link_params[:controller] = controller if controller.present?
      link_params[:action] = action if action.present?
      link_params[:page] = page if page.present?
      link_params[:items] = items if items.present?
      link_params[:disable_paging] = disable_paging if disable_paging.present?
      link_params[:filter_partial_match] = filter_text if filter_text.present?
      link_params[:order_by] = order_by if order_by.present?
      link_params[:direction] = direction if direction.present?
      link_params.merge!(additional_params) if additional_params.present?

      if filter_generic_keys.present?
        filter_generic_keys.each do |key, value|
          link_params[:"filter_#{key}"] = value
        end
      end

      url_helpers.url_for(link_params)
    end
  end
end
