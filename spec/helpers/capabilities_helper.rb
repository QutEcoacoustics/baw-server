# frozen_string_literal: true

require 'helpers/shared_examples/capabilities_for'
require 'helpers/permissions_helper'

module CapabilitiesHelper
  module ExampleGroup
    STANDARD_USERS = PermissionsHelpers::ExampleGroup::STANDARD_USERS

    def self.extended(base)
      base.define_metadata_state(:capabilities_spec, default: {})

      base.after do
        logger.info(trace_metadata(:capabilities_spec))
      end
    end

    def given_the_route(route, &route_params)
      spec = get_capabilities_spec
      spec[:route] = route
      spec[:route_params] = route_params

      set_capabilities_spec(spec)
    end

    def has_list_capability(name, can_users:, cannot_users:, unsure_users: [], unauthorized_users: [])
      spec = get_capabilities_spec

      users = normalize_users(
        "list: #{name}",
        can: can_users,
        cannot: cannot_users,
        unsure: unsure_users,
        unauthorized: unauthorized_users
      )

      users.each do |user, can|
        it_behaves_like 'capabilities for', {
          route: spec[:route],
          route_params: spec[:route_params],
          user: user,
          name: name,
          expected_can: can,
          actions: [
            { verb: :get, path: '' },
            { verb: :get, path: 'filter' }
          ]
        }
      end

      set_capabilities_spec(spec)
    end

    def has_item_capability(name, can_users:, cannot_users:, unsure_users: [], unauthorized_users: [])
      spec = get_capabilities_spec

      users = normalize_users(
        "item: #{name}",
        can: can_users,
        cannot: cannot_users,
        unsure: unsure_users,
        unauthorized: unauthorized_users
      )

      users.each do |user, can|
        it_behaves_like 'capabilities for', {
          route: spec[:route],
          route_params: spec[:route_params],
          user: user,
          name: name,
          expected_can: can,
          actions: [
            { verb: :get, path: '{id}' }
          ]
        }
      end

      set_capabilities_spec(spec)
    end

    private

    def validate_no_overlap(name, can:, cannot:, unsure:, unauthorized:)
      message = "The capability spec for the `:#{name}` capability"
      # find if there are any overlaps
      intersection = [can, cannot, unsure, unauthorized]
                     .combination(2)
                     .map { |a, b| (a & b).to_a }
                     .flatten
      raise "#{message} has overlapping users. The following are duplicates: #{intersection}" if intersection.any?
    end

    def validate_all_users(name, can:, cannot:, unsure:, unauthorized:)
      # find if there are any overlaps
      all = (can + cannot + unsure + unauthorized)
      missing = STANDARD_USERS - all
      undefined = all - STANDARD_USERS
      raise "Not all users tested for #{name}. The following are missing: #{missing.to_a}" unless missing.empty?

      raise "Unknown user tested for #{name}. The following are undefined: #{undefined.to_a}" unless undefined.empty?
    end

    def normalize_users(name, can:, cannot:, unsure:, unauthorized:)
      can = Set.new(can)
      cannot = Set.new(cannot)
      unsure = Set.new(unsure)

      validate_no_overlap(name, can: can, cannot: cannot, unsure: unsure, unauthorized: unauthorized)
      validate_all_users(name, can: can, cannot: cannot, unsure: unsure, unauthorized: unauthorized)

      [
        *can.map { |u| [u, true] },
        *cannot.map { |u| [u, false] },
        *unsure.map { |u| [u, nil] },
        *unauthorized.map { |u| [u, :unauthorized] }
      ]
    end
  end
end
