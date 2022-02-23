# frozen_string_literal: true

require 'helpers/shared_examples/permissions_for'

# rubocop:disable Metrics/ModuleLength
module PermissionsHelpers
  module ExampleGroup
    STANDARD_ACTIONS = Set[:index, :show, :create, :update, :destroy, :filter, :new].freeze
    STANDARD_USERS = Set[:admin, :harvester, :owner, :writer, :reader, :no_access, :invalid, :anonymous].freeze

    def self.extended(base)
      base.class_attribute :registered_users, :route, :route_params, :request_body_options,
        :expected_list_items_callback, :update_attrs_subset

      base.registered_users = Set.new
      base.after(:all) do
        users_not_tested = STANDARD_USERS - base.registered_users

        next if users_not_tested.empty?

        route = base.instance_variable_get(:@route)
        untested = users_not_tested.to_a.join(', ')
        raise "Some users were not tested by the permissions spec for #{route}. Add tests for the following users: #{untested}"
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
              traits: traits,
              factory: factory,
              factory_args: factory_args.nil? ? {} : instance_exec(&factory_args)
            ),
            :json
          ]
        },
        update: proc {
          [
            body_attributes_for(
              model_name,
              factory: factory,
              traits: traits,
              subset: update_attrs_subset,
              factory_args: factory_args.nil? ? {} : instance_exec(&factory_args)
            ),
            :json
          ]
        }
      })
    end

    # Indicate we're not testing any method that sends a request body to update a model.
    # This is POST/PUT/PATCH verbs or #create/#update actions.
    def with_idempotent_requests_only
      error = lambda {
        raise 'a method that needs a request body was used, but this set of specs was marked as only testing idempotent methods'
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

    def the_users(*users, **keyword_args)
      users.each do |user|
        the_user(user, **keyword_args)
      end
    end

    # Run permissions tests for users and actions.
    # Designed to be used to to test all users and actions;
    # it will error if any of the standard users or actions
    # are missed.
    def the_user(user, can_do:, and_cannot_do: Set[], fails_with: :forbidden)
      can_do = Set.new(can_do)
      and_cannot_do = Set.new(and_cannot_do)

      validate_tests_all(user, can_do: can_do, and_cannot_do: and_cannot_do)

      ensures(user, can: can_do, cannot: and_cannot_do, fails_with: fails_with)
    end

    # Run permissions tests for users and actions.
    # Similar to `the_users` except it does not error if all
    # cases are not covered. Designed to test edge cases or
    # smaller sets of permissions
    def ensures(*users, can: Set[], cannot: Set[], fails_with: :forbidden)
      users.each do |user|
        validate_dsl_state

        can = Set.new(can)
        cannot = Set.new(cannot)

        validate_sets(user, can_do: can, and_cannot_do: cannot)

        actions = can.map { |x| normalize(x, route, :successful, true) } +
                  cannot.map { |x| normalize(x, route, fails_with, false) }

        it_behaves_like 'permissions for', {
          route: route,
          route_params: route_params,
          user: user,
          actions: actions,
          request_body_options: request_body_options,
          expected_list_items_callback: expected_list_items_callback,
          update_attrs_subset: update_attrs_subset
        }

        registered_users << user
      end
    end

    def everything
      STANDARD_ACTIONS
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

    private

    VERB_LOOKUP = {
      index: { path: '', verb: :get, expect: :list },
      show: { path: '{id}', verb: :get, expect: :single },
      create: { path: '', verb: :post, expect: :created },
      update: { path: '{id}', verb: :put, expect: :single },
      destroy: { path: '{id}', verb: :delete, expect: :nothing },
      new: { path: 'new', verb: :get, expect: :template },
      filter: { path: 'filter', verb: :get, expect: :list }
    }.freeze

    def validate_dsl_state
      raise 'route must be set' if route.nil?
      raise 'route parameters must be set' if route_params.nil?
      if request_body_options.nil?
        raise 'a request_body_options must be set via `using_the_factory` or `send_create_body` and `send_update_body`'
      end
    end

    def validate_sets(user, can_do:, and_cannot_do:)
      message = "The permission spec for the `:#{user}` user"
      # find if there are any overlaps
      intersection = can_do & and_cannot_do
      if intersection.any?
        raise "#{message} has overlapping can and cannot permissions. The following are duplicates: #{intersection}"
      end
    end

    def validate_tests_all(user, can_do:, and_cannot_do:)
      message = "The permission spec for the `:#{user}` user"
      # ensure we've covered all the standard actions
      get_action = ->(x) { x.is_a?(Symbol) ? x : x[:action] }
      missing = STANDARD_ACTIONS - (can_do + and_cannot_do).map(&get_action)
      return if missing.empty?

      raise "#{message} does not cover all standard actions. The following are missing: #{missing}"
    end

    def normalize(item, route, expected_status, can)
      result =
        if item.is_a?(Symbol) && VERB_LOOKUP.key?(item)
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

      validate_action_hash(result, item)

      route_param = result[:path]
      result[:path] = Addressable::Template.new("#{route}/#{route_param}")
      result
    end

    def validate_action_hash(action, item)
      if ![:list, :single, :nothing, :template, :created].include?(action[:expect]) && !action[:expect].is_a?(Proc)
        raise "expect value #{action[:expect]} is not recognized"
      end

      return if action.is_a?(Hash) &&
                action.key?(:path) &&
                action.key?(:verb) &&
                action.key?(:action)

      raise "item `#{item}` is not valid. It must be a standard action symbol or a hash with the keys :path and :verb and :action and :expect"
    end
  end
end
