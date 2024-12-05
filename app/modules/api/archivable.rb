# frozen_string_literal: true

module Api
  # Helpers for archiving (soft deleting resources).
  # When included, the controller will have the following actions:
  # - destroy
  # - destroy_permanently (if the model is discardable)
  # - recover (if the model is discardable)
  #
  # The controller will also have a `with_archived?` predicate method
  # that will return true if the `ARCHIVE_ACCESS_PARAM` is set to true.
  #
  # The controller will also define the following callbacks:
  # - before_destroy, after_destroy, around_destroy
  # - before_recover, after_recover, around_recover
  # - before_destroy_permanently, after_destroy_permanently, around_destroy_permanently
  #
  # The callbacks will halt execution if a render or redirect has been called in
  # a before callback.
  module Archivable
    UNAUTHORIZED_MESSAGE = 'You are not authorized to access archived resources'
    ARCHIVE_ACCESS_PARAM = :with_archived

    extend ActiveSupport::Callbacks

    def self.included(base)
      base.extend(ClassMethods)
      base.define_callbacks(
        :destroy, :recover, :destroy_permanently,
        scope: [:kind, :name],
        # just like controller callbacks, we halt execution if the
        # a render or redirect has been called
        # https://github.com/rails/rails/blob/a11f0a63673d274c59c69c2688c63ba303b86193/actionpack/lib/abstract_controller/callbacks.rb#L34C36-L34C112
        terminator: lambda { |controller, result_lambda|
                      result_lambda.call
                      controller.performed?
                    }
      )
    end

    # Class methods
    module ClassMethods
      def inherited(subclass)
        # Remove unnecessary methods if the model is not discardable.
        # This shouldn't be necessary as the actions aren't routable, but
        # it leaves no room for mistakes.
        if subclass.controller_path.present?
          model_class = subclass.controller_path.classify.safe_constantize
          # could be nil if the controller is not a resource controller
          is_model = model_class.present? && model_class < ApplicationRecord
          discardable = model_class&.try(:discardable?)

          unless is_model && discardable
            subclass.undef_method(:destroy_permanently) if subclass.method_defined?(:destroy_permanently)
            subclass.undef_method(:recover) if subclass.method_defined?(:recover)
          end
        end

        super
      end

      [:before, :after, :around].each do |callback_type|
        [:destroy, :recover, :destroy_permanently].each do |action|
          define_method("#{callback_type}_#{action}") do |*filter_list, &blk|
            set_callback(action, callback_type, *filter_list, &blk)
          end
        end
      end
    end

    # DELETE /{resource}/:id
    def destroy
      do_load_resource
      do_authorize_instance

      run_callbacks :destroy do
        if resource_class.discardable?
          get_resource.discard!
        else
          get_resource.destroy!
        end

        add_archived_at_header(get_resource)
        respond_destroy
      end
    end

    # ! This method is dynamically undefined in the controller if the associated
    # ! model is not discardable
    # DELETE /{resource}/:id/destroy
    # POST /{resource}/:id/destroy
    def destroy_permanently
      do_load_resource
      do_authorize_instance

      run_callbacks :destroy_permanently do
        get_resource.destroy!

        respond_destroy
      end
    end

    # ! This method is dynamically undefined in the controller if the associated
    # ! model is not discardable
    # POST /{resource}/:id/recover
    def recover
      do_load_resource
      do_authorize_instance

      run_callbacks :recover do
        get_resource.undiscard!

        expires_now
        location = url_for(action: :show, only_path: true)
        head :no_content, location:, content_type: 'application/json'
      end
    end

    private

    def available_actions
      others = super
      return others unless resource_class.discardable?

      begin
        others + [
          {
            text: 'destroy',
            url: url_for(action: 'destroy_permanently', only_path: true)
          },
          {
            text: 'recover',
            url: url_for(action: 'recover', only_path: true)
          }
        ]
      rescue ActionController::UrlGenerationError
        # most of our routes don't support the extra actions yet
        others
      end
    end

    # Check if the `ARCHIVE_ACCESS_PARAM` is set and also
    # normalizes the value to a boolean inside params.
    # @return [Boolean]
    def with_archived?
      return @with_archived unless @with_archived.nil?

      if params.key?(ARCHIVE_ACCESS_PARAM)

        value = params.fetch(ARCHIVE_ACCESS_PARAM)

        @with_archived = value.blank? ? true : ActiveRecord::Type::Boolean.new.cast(value)

        # add the standardized value to the params so other methods can use it
        params[ARCHIVE_ACCESS_PARAM] = @with_archived
      else
        # don't add to params here, so we don't emit the param in the response
        # if it was never set

        # but we still report that the archive option was not enabled
        @with_archived = false
      end

      @with_archived
    end

    # If the record is archived, this will raise an error
    # unless we're in the `:destroy_permanently` or `:recover` actions or
    # the user is allowed to access archived records.
    # Should be called after do_load_resource and after authorization
    def check_if_archived!
      resource = get_resource

      # has the item been archived
      return unless resource&.discardable?
      return unless resource&.discarded?

      # only allow destroy (permanent) and recover actions
      return if [:destroy_permanently, :recover].include?(action_name_sym)

      add_archived_at_header(get_resource)

      # lastly check if we're allowed to bypass the archived status
      return if authorize_archived_access_for_instance!

      raise CustomErrors::GoneError
    end

    def authorize_archived_access_for_instance!
      return false unless with_archived?

      authorize! :access_archived, get_resource, message: UNAUTHORIZED_MESSAGE

      true
    end

    def authorize_archived_access_for_class!
      return false unless with_archived?

      authorize! :access_archived, resource_class, message: UNAUTHORIZED_MESSAGE

      true
    end

    # Add archived at header to HTTP response
    # @param [ActiveRecord::Base] model
    # @return [void]
    def add_archived_at_header(model)
      # only add the header if the model is paranoid and has been archived
      # and has not been fully destroyed
      return unless model.class.discardable?

      return unless model.discarded?

      return if model.destroyed?

      response.headers['X-Archived-At'] = model.deleted_at.httpdate
    end
  end
end
