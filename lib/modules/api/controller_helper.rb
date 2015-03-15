module Api
  module ControllerHelper
    extend ActiveSupport::Concern

    # based on https://codelation.com/blog/rails-restful-api-just-add-water
    private

    # The singular name for the resource class based on the controller
    # @return [String]
    def resource_name
      @resource_name ||= self.controller_name.singularize
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

    # Returns the resource from the created instance variable
    # @return [Object]
    def get_resource_plural
      instance_variable_get("@#{resource_name_plural}")
    end

    # The resource class based on the controller
    # @return [Class]
    def resource_class
      @resource_class ||= resource_name.classify.constantize
    end

    # Set a <user>_id to the current_user's id
    # @param [String, Symbol] attribute_name
    # @return [void]
    def set_user_id(attribute_name)
      responds = get_resource.respond_to?("#{attribute_name}=".to_sym)
      is_blank = responds ? get_resource.send("#{attribute_name}".to_sym).blank? : false
      current_user_valid = !current_user.blank?
      if responds && is_blank && current_user_valid
        get_resource.send("#{attribute_name}=".to_sym, current_user.id)
      end
    end

    def respond_index(opts = {})
      items = get_resource_plural.map { |item|
        respond_modify(item)
      }
      built_response = Settings.api_response.build(:ok, items, opts)
      render json: built_response, status: :ok, layout: false
    end

    # also used for update_success and new
    def respond_show
      item_resource = get_resource

      item = respond_modify(item_resource)

      built_response = Settings.api_response.build(:ok, item)
      render json: built_response, status: :ok, layout: false
    end

    def respond_create_success(location = nil)
      item_resource = get_resource

      item = respond_modify(item_resource)

      built_response = Settings.api_response.build(:created, item)
      render json: built_response, status: :created, location: location.blank? ? get_resource : location, layout: false
    end

    # used for create_fail and update_fail
    def respond_change_fail
      built_response = Settings.api_response.build(:unprocessable_entity, nil, {error_details: get_resource.errors})
      render json: built_response, status: :unprocessable_entity
    end

    def respond_destroy
      built_response = Settings.api_response.build(:no_content, nil)
      render json: built_response, status: :no_content
    end

    def respond_filter(content, status_symbol)
      render json: content, status: status_symbol, content_type: 'application/json'
    end

    def attributes_and_authorize(custom_params = nil)
      # need to do what cancan would otherwise do due to before_action creating instance variable, so cancan
      # assumes already authorized
      # see https://github.com/CanCanCommunity/cancancan/wiki/Controller-Authorization-Example
      current_ability.attributes_for(action_name.to_sym, resource_class).each do |key, value|
        get_resource.send("#{key}=", value)
      end
      capture_params = custom_params.nil? ? params[resource_name.to_sym] : custom_params
      get_resource.attributes = capture_params if !capture_params.blank? && capture_params.is_a?(Hash)
      do_authorize!
    end

    def do_authorize!
      authorize! action_name.to_sym, get_resource
    end

    # Allow extra fields to be added to response.
    # @param [Object] item_resource
    # @return [String] json
    def respond_modify(item_resource)
      extra_hash = {}
      if defined?(api_custom_response) == 'method'
        item_resource, extra_hash = api_custom_response(item_resource)
      end
      fields = item_resource.class.filter_settings[:render_fields]
      item_resource.as_json(only: fields).merge(extra_hash)
    end

    def api_filter_params
      # for filter api, all validation is done in modules rather than in strong parameters.
      params.permit!
    end

  end
end
