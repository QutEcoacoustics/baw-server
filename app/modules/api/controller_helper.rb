# frozen_string_literal: true

module Api
  # Helpers for controllers that conform to our conventions
  # rubocop:disable Metrics/ModuleLength
  module ControllerHelper
    extend ActiveSupport::Concern

    # based on https://codelation.com/restful-rails-api-just-add-water/
    private

    # The singular name for the resource class based on the controller
    # @return [String]
    def resource_name
      @resource_name ||= controller_name.singularize
    end

    # The name of the controller including namespaces
    # @return [String]
    def resource_path
      @resource_path ||= controller_path.singularize
    end

    # The plural name for the resource class based on the controller
    # @return [String]
    def resource_name_plural
      @resource_name_plural ||= resource_name.pluralize
    end

    # Returns the resource from the created instance variable
    # @return [Object]
    def get_resource
      instance_variable_get("@#{resource_name}")
    end

    # Sets the resource instance variable to the given value
    # @param [Object] value
    # @return [void]
    def set_resource(value)
      instance_variable_set("@#{resource_name}", value)
    end

    # Returns the resource from the created instance variable
    # @return [Object]
    def get_resource_plural
      instance_variable_get("@#{resource_name_plural}")
    end

    # Sets the resource instance plural variable to the given value
    # @param [Object] value
    # @return [void]
    def set_resource_plural(value)
      instance_variable_set("@#{resource_name_plural}", value)
    end

    # The resource class based on the controller
    # @return [Class]
    def resource_class
      @resource_class ||= resource_path.classify.constantize
    end

    # Only needed for single responses because for filter/index responses
    # We can customize the projection and that is passed through in opts.
    # No customization for single responses, so we use the default projected fields.
    def default_projected_fields_for_single
      filter_settings[:render_fields].to_set
    end

    # The default parameters to give to filter query single.
    def default_filter_parameters_for_single
      {
        # by default allow archived records to be loaded
        # we can issue GONE responses if the record is archived
        # If we're not allowed access `check_if_archived` will raise an error
        Archivable::ARCHIVE_ACCESS_PARAM => true
      }
    end

    # Simply gets the id route parameter.
    # Defined so you can override it in your controller if you need to.
    # @return [String, Integer, nil]
    def id_param
      params[:id]
    end

    # find the resource using the id_param
    # Defined so you can override it in your controller if you need to.
    # @param base_query [ActiveRecord::Relation] the base query to use to find the resource
    # @return [ApplicationRecord]
    # @raise [ActiveRecord::RecordNotFound] if the resource is not found
    def find_resource(base_query)
      base_query.find(id_param)
    end

    # Set a <user>_id to the current_user's id
    # @param [String, Symbol] attribute_name
    # @return [void]
    def set_user_id(attribute_name)
      responds = get_resource.respond_to?(:"#{attribute_name}=")
      is_blank = responds ? get_resource.send(attribute_name.to_s.to_sym).blank? : false
      current_user_valid = current_user.present?
      get_resource.send(:"#{attribute_name}=", current_user.id) if responds && is_blank && current_user_valid
    end

    def respond_index(opts = {}, filter_settings: nil)
      opts[:projected_fields] ||= default_projected_fields_for_single
      filter_settings ||= self.filter_settings

      items = get_resource_plural.map { |item|
        Settings.api_response.prepare(item, current_user, nil, opts, filter_settings:)
      }

      Settings.api_response.add_capabilities!(opts, resource_class)

      render_format(items, opts)
    end

    # also used for update_success and new
    def respond_show(additional_data = nil, filter_settings: nil)
      item_resource = get_or_reload_resource
      filter_settings ||= self.filter_settings

      opts = {
        projected_fields: default_projected_fields_for_single
      }

      item = Settings.api_response.prepare(item_resource, current_user, additional_data, opts, filter_settings:)

      Settings.api_response.add_capabilities!(opts, resource_class, item_resource)

      built_response = Settings.api_response.build(:ok, item, opts)
      render json: built_response, status: :ok, layout: false
    end

    def respond_new(filter_settings: nil)
      item_resource = get_resource

      filter_settings ||= self.filter_settings

      item = Settings.api_response.prepare_new(item_resource, current_user, filter_settings:)

      opts = {}
      # Can't think of a valid context for this currently
      #Settings.api_response.add_capabilities!(opts, resource_class, item_resource)

      built_response = Settings.api_response.build(:ok, item, opts)
      render json: built_response, status: :ok, layout: false
    end

    def respond_create_success(location = nil, additional_data = nil, filter_settings: nil)
      item_resource = get_or_reload_resource
      filter_settings ||= self.filter_settings

      opts = {
        projected_fields: default_projected_fields_for_single
      }

      item = Settings.api_response.prepare(item_resource, current_user, additional_data, opts, filter_settings:)

      Settings.api_response.add_capabilities!(opts, resource_class, item_resource)

      built_response = Settings.api_response.build(:created, item, opts)
      render json: built_response, status: :created, location: location.presence || item_resource, layout: false
    end

    # used for create fail and update fail
    def respond_change_fail
      built_response = Settings.api_response.build(
        :unprocessable_content,
        nil,
        {
          error_details: 'Record could not be saved',
          error_info: get_resource.errors
        }
      )
      render json: built_response, status: :unprocessable_content, layout: false
    end

    def respond_change_fail_with_resource(additional_data = nil, filter_settings: nil)
      item_resource = get_resource
      item_resource = get_or_reload_resource if item_resource.persisted?
      filter_settings ||= self.filter_settings

      opts = {
        projected_fields: default_projected_fields_for_single
      }

      item = Settings.api_response.prepare(item_resource, current_user, additional_data, opts, filter_settings:)

      built_response = Settings.api_response.build(
        :unprocessable_content,
        item,
        {
          error_details: 'Record could not be saved',
          error_info: item_resource.errors
        }
      )
      render json: built_response, status: :unprocessable_content, layout: false
    end

    def respond_destroy
      built_response = Settings.api_response.build(:no_content, nil)
      render json: built_response, status: :no_content, layout: false
    end

    def respond_error(status_symbol, message, opts = {})
      render_error(
        status_symbol,
        message,
        nil,
        'respond_error',
        opts
      )
    end

    def respond_filter(content, opts = {}, filter_settings: nil)
      filter_settings ||= self.filter_settings

      items = content.map { |item|
        Settings.api_response.prepare(item, current_user, nil, opts, filter_settings:)
      }

      Settings.api_response.add_capabilities!(opts, resource_class)

      render_format(items, opts)
    end

    def filename(opts, format)
      # a rudimentary way of encoding filtering parameters into a filename
      # e.g. {id: {in: [1,2,3]}, name: {eq: '\n'}}  ==> id_in_1_2_3_name_eq_n
      # AT 2025: I decided not to include default filters in the filename
      # because they don't add enough new information and just bloat otherwise
      # simple filter file names
      filter = opts[:filter_without_defaults]
      filter_part = filter.blank? ? '' : "_#{filter.to_json.gsub(/["{}\\\[\]]/, '').gsub(/:|,/, '_')}"
      "#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}_#{resource_name_plural}#{filter_part}.#{format}"
    end

    def render_format(items, opts)
      respond_to do |format|
        format.json do
          content_type = 'application/json'
          built_response = Settings.api_response.build(:ok, items, opts)

          if request.head?
            head :ok, { content_length: built_response.to_json.bytesize, content_type: }
          else
            render json: built_response, status: :ok, content_type:, layout: false
          end
        end
        format.csv do
          content_type = 'text/csv'
          headers['Content-Disposition'] = "attachment; filename=\"#{filename(opts, 'csv')}\""

          body = items.blank? ? '' : Api::Csv.dump(Array(items))

          if request.head?
            head :ok, { content_length: body.bytesize, content_type: }
          else
            render body:, status: :ok, content_type:, layout: false
          end
        end
      end
    end

    # Intended to take filter options and normalize them for a subsequent filter
    # request.
    # @return [Hash] - a hash including filter, paging, and sorting sub-hashes suitable for
    #  passing to the filter POST method.
    def build_filter_response_as_filter_query(content, opts = {})
      # add custom fields
      items = content.map { |item|
        Settings.api_response.prepare(item, current_user, nil, opts)
      }

      # build out the normal response
      filter_response = Settings.api_response.build(:ok, items, opts.except(:total))

      # choose a subset of response to format as a request filter
      # data is discarded here
      filter = filter_response[:meta].except(:status, :message, :paging, :capabilities)
      if opts[:page].present? && opts[:items].present?
        filter[:paging] = {
          items: opts[:items]
        }
      end

      filter
    end

    # Get filter settings for the current resource type.
    def filter_settings
      resource_class.filter_settings
    end

    def api_filter_params
      # for filter api, all validation is done in modules rather than in strong parameters.
      params.permit!
    end

    # Filter out only paging parameters from the request.
    # Used in endpoints that are not standard but still need paging.
    # @param [Hash] route_parameters - additional route parameters to include in
    #   the paging hash that might be needed to reconstruct the url.
    def paging_only_params(route_parameters)
      # also add in :controller and :action
      # these are normally supplied by filter_params but don't tend to be used
      # when this method is called because it some kind of custom endpoint.
      Filter::Parse.parse_paging_only(api_filter_params).merge({
        controller: controller_name,
        action: action_name,
        additional_params: route_parameters
      })
    end

    # Replacement methods for CanCanCan authorize_resource, load_resource, load_and_authorize_resource.

    def do_set_attributes(custom_params = nil)
      # see https://github.com/CanCanCommunity/cancancan/wiki/Controller-Authorization-Example
      current_ability.attributes_for(action_name.to_sym, resource_class).each do |key, value|
        get_resource.send("#{key}=", value)
      end

      custom_params = params[resource_name.to_sym] if custom_params.nil? && params.permitted?

      return if custom_params.blank?

      custom_params = custom_params.to_h if custom_params.is_a? ActionController::Parameters

      raise TypeError, 'expect `custom_params` to be a hash' unless custom_params.is_a? Hash

      get_resource.attributes = custom_params
    end

    def do_new_resource
      set_resource(resource_class.new)
    end

    def do_load_resource
      # we augment the query here to allow us to fetch information needed for custom fields
      # Fixes https://github.com/QutEcoacoustics/baw-server/issues/565
      current_filter = Filter::Single.new(default_filter_parameters_for_single, resource_class, filter_settings)

      resource = find_resource(current_filter.query)

      set_resource(resource)
    end

    # Find or create a resource and set its attributes using the provided parameters.
    # For existing resources, updates attributes excluding find_keys.
    # For new resources, sets all provided attributes.
    # @param [ActionController::Parameters] upsert_params
    # @param [Array<Symbol>] find_keys The keys to use from upsert_params for finding the resource
    def do_load_or_new_resource(upsert_params, find_keys:)
      raise ArgumentError, 'find_keys must not be empty' if find_keys.blank?
      raise ArgumentError, 'find_keys must contain symbols' unless find_keys.all?(Symbol)

      current_filter = Filter::Single.new(default_filter_parameters_for_single, resource_class, filter_settings)

      # we mimic find_sole_by here but we don't necessarily want raise to if not found
      # all `sole` does is retrieve two records - if there is more than one it raises
      resource, undesired = current_filter.query.where(upsert_params.slice(*find_keys)).take(2)

      # ! Note the detection for faulty keys will only work if there is more
      # ! than one entry already in the database. If there is exactly one
      # ! we could just be fetching the incorrect resource instead.

      # not discerning enough
      raise CustomErrors::UpsertMatchNotUnique.new(find_keys:) if undesired.present?

      if resource.nil?
        # create
        do_new_resource
        do_set_attributes(upsert_params)
      else
        # update
        set_resource(resource)
        do_set_attributes(upsert_params.except(*find_keys))
      end
    end

    # To return any resource that has custom fields,
    # we need to reload it to ensure the custom fields are calculated.
    def get_or_reload_resource
      resource = get_resource

      raise 'Resource not set' if resource.nil?
      # In two cases (dry commit for AEIF, and failed validation for AEIF)
      # the resource is not saved. In this case there's no way we can return
      # custom fields if the object isn't in the database.
      return resource unless resource.persisted?

      # If custom_field2 isn't even in the resource, not reason to continue
      return resource unless filter_settings in { render_fields:, custom_fields2: }

      custom_calculated_fields = custom_fields2.keys.filter { |key| Filter::CustomField.custom_field_is_calculated?(key, custom_fields2) }
      render_fields_include_custom_fields = render_fields.intersect?(custom_calculated_fields)

      return resource unless render_fields_include_custom_fields

      # we augment the query here to allow us to fetch information needed for custom fields
      # Fixes https://github.com/QutEcoacoustics/baw-server/issues/565
      current_filter = Filter::Single.new(default_filter_parameters_for_single, resource_class, filter_settings)

      resource = current_filter.query.find(resource.id)

      set_resource(resource)
    end

    def do_authorize_instance(custom_action_name = nil, custom_resource = nil)
      action = action_name_sym(custom_action_name)

      do_authorize_jwt(action)

      authorize! action, (custom_resource || get_resource)

      # IFF someone sent the ARCHIVE_ACCESS_PARAM,
      # and the resource is discardable,
      # we check if we're allowed to access this archived record
      check_if_archived!
    end

    def do_authorize_class(custom_action_name = nil, custom_class = nil)
      action = action_name_sym(custom_action_name)

      do_authorize_jwt(action)

      authorize! action, (custom_class || resource_class)

      # IFF someone sent the ARCHIVE_ACCESS_PARAM,
      # we check if we're allowed to access archived records
      authorize_archived_access_for_class! if with_archived?
    end

    # Our JWT tokens can include claims that limit access to a resource or action.
    # This does not allow any additional access (the cancan rules still apply), but
    # it will short-circuit and fail if the JWT does not allow access.
    def do_authorize_jwt(action)
      # @type [::Api::Jwt::Token]
      token = request.env.fetch(Api::AuthStrategies::Jwt::ENV_KEY, nil)

      return if token.nil?

      if token.resource && token.resource.to_s != controller_name
        raise ::Api::ApiAuth::AccessDenied, 'JWT does not allow access to this resource'
      end

      return unless token.action && token.action.to_sym != action

      raise ::Api::ApiAuth::AccessDenied, 'JWT does not allow access to this action'
    end

    def action_name_sym(custom_action_name = nil)
      (custom_action_name || action_name).to_sym
    end
  end
end
