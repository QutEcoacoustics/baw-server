# frozen_string_literal: true

require 'support/shared_examples/permissions_for'

# rubocop:disable Metrics/ModuleLength
module PermissionsHelpers
  module ExampleGroup
    STANDARD_ACTIONS = Set[:index, :show, :create, :update, :destroy, :filter, :new].freeze
    STANDARD_USERS = Set[:admin, :harvester, :owner, :writer, :reader, :no_access, :invalid, :anonymous].freeze

    def self.extended(base)
      base.class_attribute :registered_users_and_actions, :route, :route_params, :request_body_options,
        :expected_list_items_callback, :update_attrs_subset, :before_request_callback,
        :custom_actions, :custom_users, :skip_check

      # ensure cookies are disabled
      # this only applies if there is more than request per test
      # but it's better to be safe than sorry
      base.disable_cookie_jar

      base.registered_users_and_actions = ({})
      base.custom_users ||= Set.new
      base.custom_actions ||= {}
      base.after(:all) do
        users = STANDARD_USERS + custom_users
        expected_actions = STANDARD_ACTIONS + custom_actions.keys
        missing_users = users - registered_users_and_actions.keys.to_set
        missing_actions = registered_users_and_actions.reduce('') { |message, kvp|
          kvp => [user, actions]
          missing_actions = expected_actions - actions

          missing_actions -= skip_check[user] if skip_check&.key?(user)

          unless missing_actions.empty?
            message += "    - `#{user}` is missing actions: #{missing_actions.format_inline_list}\n"
          end
          message
        }

        next if missing_users.empty? && missing_actions.blank?

        route = base.route
        untested = missing_users.format_inline_list
        message = "Some users or actions were not tested by the permissions spec for #{route}. Add tests for the following:"
        message << "\n  - users: #{untested}" unless missing_users.empty?
        message << "\n  - actions:\n#{missing_actions}" if missing_actions.present?
        raise message
      end
    end

    def given_the_route(route, &route_params)
      self.route = route
      self.route_params = route_params
    end

    def using_the_factory(factory, traits: [], model_name: factory, factory_args: nil)
      (self.request_body_options ||= {}).merge!({
        create: proc {
          [
            body_attributes_for(
              model_name,
              traits:,
              factory:,
              factory_args: factory_args.nil? ? {} : instance_exec(&factory_args)
            ),
            :json
          ]
        },
        update: proc {
          [
            body_attributes_for(
              model_name,
              factory:,
              traits:,
              subset: update_attrs_subset,
              factory_args: factory_args.nil? ? {} : instance_exec(&factory_args)
            ),
            :json
          ]
        }
      })
    end

    # specifies a custom action that is registered and that should be
    # tested with all users
    # @param name [Symbol] the name of the action
    # @param path [Addressable::URI] the path to the action
    # @param verb [Symbol] the HTTP verb to use
    # @param expect [Symbol] the expected status of the response
    # @param before [Proc] a block that is executed before the action is called
    #  the block should take two arguments, the user and the action.
    def with_custom_action(name, path:, verb:, expect:, body: nil, before: nil)
      self.custom_actions ||= {}
      self.custom_actions[name] = {
        path:,
        verb:,
        expect:,
        body:,
        before:
      }
    end

    # A macro that registers 3 additional actions for archivable resources
    # to check:
    # - destroy_permanently
    # - recover
    # - show_archived
    # The block is used to fetch the current subject instance
    # and update it to be archived
    # @param block [Proc] a block that returns the current instance
    def is_archivable(&)
      with_custom_action :destroy_permanently, path: '{id}/destroy', verb: :delete, expect: :nothing
      with_custom_action(
        :recover,
        path: '{id}/recover',
        verb: :post,
        expect: :nothing,
        before: proc { |_user, _action|
                  instance = instance_exec(&)
                  instance.update_attribute(
                    :deleted_at, Time.zone.now
                  )
                }
      )

      # using ?with_archived=true to show archived records
      # is a separate permission
      # and since it executes a different query it should be
      # tested as well for all users
      with_custom_action(
        :show_archived,
        path: "?#{::Api::Archivable::ARCHIVE_ACCESS_PARAM}",
        verb: :get,
        expect: :list
      )
    end

    def with_custom_user(name)
      self.custom_users ||= Set.new
      self.custom_users << name
    end

    # Bypass the automatic permissions coverage check for the given users and actions.
    # This should only be used when testing controllers that are not part of the standard
    # permissions matrix.
    def do_not_check_permissions_for(users, actions)
      self.skip_check ||= {}

      users.each do |user|
        existing = self.skip_check.fetch(user, [])
        existing.push(*actions)
        self.skip_check[user] = existing
      end
    end

    # Indicate we're not testing any method that sends a request body to update a model.
    # This is POST/PUT/PATCH verbs or #create/#update actions.
    def with_idempotent_requests_only
      error = lambda {
        Rails.logger.warn 'a method that needs a request body was used, but this set of specs was marked as only testing idempotent methods'
        nil
      }
      send_create_body(&error)
      send_update_body(&error)
    end

    def send_create_body(&block)
      (self.request_body_options ||= {})[:create] = block
    end

    def send_update_body(&block)
      (self.request_body_options ||= {})[:update] = block
    end

    def for_lists_expects(&expected_list_items_callback)
      self.expected_list_items_callback = expected_list_items_callback
    end

    def when_updating_send_only(*attrs)
      self.update_attrs_subset = attrs
    end

    def before_request(action = nil, &before_request_callback)
      self.before_request_callback ||= {}
      action ||= :all
      self.before_request_callback[action] = before_request_callback
    end

    def the_users(*users, **keyword_args)
      users.each do |user|
        the_user(user, **keyword_args)
      end
    end

    # Run permissions tests for users and actions.
    def the_user(user, can_do:, and_cannot_do: nil, fails_with: :forbidden)
      can_do = Set.new(can_do)

      and_cannot_do = and_cannot_do.nil? ? everything - can_do : Set.new(and_cannot_do)

      ensures(user, can: can_do, cannot: and_cannot_do, fails_with:)
    end

    # Run permissions tests for users and actions.
    def ensures(*users, can: Set[], cannot: Set[], fails_with: :forbidden)
      users.each do |user|
        validate_dsl_state
        unless all_users.include?(user)
          raise "The user `#{user}` is not recognized, " \
                "use `with_custom_user :#{user}` to add another user to the test matrix"
        end

        can = Array(can) unless can.is_a?(Enumerable)
        cannot = Array(cannot) unless cannot.is_a?(Enumerable)
        can = Set.new(can)
        cannot = Set.new(cannot)

        validate_sets(user, can_do: can, and_cannot_do: cannot)

        actions = can.map { |x| normalize(x, route, :successful, true) } +
                  cannot.map { |x| normalize(x, route, fails_with, false) }

        it_behaves_like 'permissions for', {
          route:,
          route_params:,
          user:,
          actions:,
          request_body_options:,
          expected_list_items_callback:,
          update_attrs_subset:,
          before_request_callback: self&.before_request_callback&.fetch(:all, nil)
        }

        actions_set = actions.to_set { |x| x[:action] }
        if registered_users_and_actions.key?(user)
          existing_actions = registered_users_and_actions[user]
          union = existing_actions & actions_set

          if union.any?
            raise "The permission spec for the `:#{user}` user has overlapping actions. The following are duplicates: #{union.format_inline_list}"
          end

          registered_users_and_actions[user] = existing_actions + actions_set
        else
          registered_users_and_actions[user] = actions_set
        end
      end
    end

    def everything
      STANDARD_ACTIONS + custom_actions&.keys
    end

    def everything_but_new
      # new is always accessible to everyone
      @everything_but_new ||= (STANDARD_ACTIONS - [:new]).freeze
    end

    def nothing
      @nothing ||= Set[].freeze
    end

    def reading
      @reading ||= Set[:show, :index, :filter, :new].freeze
    end

    def creation
      @creation ||= Set[:create]
    end

    def writing
      @writing ||= Set[:create, :update, :destroy].freeze
    end

    def mutation
      @mutation ||= Set[:update, :destroy].freeze
    end

    def listing
      @listing ||= Set[:index, :filter, :new].freeze
    end

    def not_listing
      @not_listing ||= (everything - listing).freeze
    end

    def everything_but_update
      @everything_but_update ||= (everything - [:update]).freeze
    end

    def advanced_archiving
      @advanced_archiving ||= Set[:show_archived, :destroy_permanently].freeze
    end

    def recovering
      @recovering ||= Set[:recover].freeze
    end

    def all_users
      STANDARD_USERS + custom_users
    end

    private

    VERB_LOOKUP = {
      index: { path: '', verb: :get, expect: :list },
      show: { path: '{id}', verb: :get, expect: :single },
      create: { path: '', verb: :post, expect: :created, body: :create },
      update: { path: '{id}', verb: :put, expect: :single, body: :update },
      destroy: { path: '{id}', verb: :delete, expect: :nothing },
      new: { path: 'new', verb: :get, expect: :template },
      filter: { path: 'filter', verb: :get, expect: :list }
    }.freeze

    def validate_dsl_state
      raise 'route must be set' if route.nil?
      raise 'route parameters must be set' if route_params.nil?
      return unless request_body_options.nil?

      raise 'a request_body_options must be set via `using_the_factory` or `send_create_body` and `send_update_body`'
    end

    def validate_sets(user, can_do:, and_cannot_do:)
      message = "The permission spec for the `:#{user}` user"
      # find if there are any overlaps
      intersection = can_do & and_cannot_do
      return unless intersection.any?

      raise "#{message} has overlapping can and cannot permissions. The following are duplicates: #{intersection}"
    end

    def normalize(item, route, expected_status, can)
      result =
        # pull custom actions first as a mechanism for
        # overriding the standard actions
        if item.is_a?(Symbol) && custom_actions.key?(item)
          custom_actions[item]
        elsif item.is_a?(Symbol) && VERB_LOOKUP.key?(item)
          VERB_LOOKUP[item]
        elsif item.is_a?(Hash)
          item
        else
          raise "Unexpected action item: #{item}"
        end

      result = result.dup
      result[:action] = item if item.is_a?(Symbol)
      result[:expected_status] = expected_status unless result.key?(:expected_status)
      result[:can] = can

      result[:body] = nil unless result.key?(:body)

      if result.key?(:before) && self.before_request_callback&.key?(result[:action])
        raise "before callback for #{result[:action]} is already
        defined. You can only define one before callback per action"
      elsif result.key?(:before)
        result[:before]
      elsif self.before_request_callback&.key?(result[:action])
        self.before_request_callback[result[:action]]
      end => before
      result[:before] = before

      validate_action_hash(result, item)

      route_param = result[:path]
      result[:path] = Addressable::Template.new("#{route}/#{route_param}")
      result
    end

    def validate_action_hash(action, item)
      if [:list, :single, :nothing, :template, :created].exclude?(action[:expect]) && !action[:expect].is_a?(Proc)
        raise "expect value #{action[:expect]} is not recognized (case: #{action}, item: #{item.inspect})"
      end

      return if action.is_a?(Hash) &&
                action.key?(:path) &&
                action.key?(:verb) &&
                action.key?(:action)

      raise "item `#{item}` is not valid. It must be a standard action symbol or a hash with the keys :path and :verb and :action and :expect"
    end
  end
end
