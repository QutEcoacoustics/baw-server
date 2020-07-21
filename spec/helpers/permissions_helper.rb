require 'helpers/creation'

module PermissionsGroupHelpers
  STANDARD_ACTIONS = Set[:index, :show, :create, :update, :destroy, :filter, :new].freeze
  STANDARD_USERS = Set[:admin, :harvester, :owner, :writer, :reader, :no_access, :invalid, :anonymous].freeze

  attr_accessor :registered_users

  def given_the_route(route, &route_params)
    @route = route
    @route_params = route_params
  end

  def using_the_factory(factory)
    @factory = factory
  end

  def and_validates_list_results(&validate_callback)
    @validate_callback = validate_callback
  end

  def the_users(*users, **keyword_args)
    users.each do |user|
      the_user(user, **keyword_args)
    end
  end

  def the_user(user, can_do:, and_cannot_do: Set[], fails_with: :forbidden)
    can_do = Set.new(can_do) unless can_do.is_a?(Set)
    and_cannot_do = Set.new(and_cannot_do) unless and_cannot_do.is_a?(Set)

    validate_sets(user, can_do: can_do, and_cannot_do: and_cannot_do)

    actions = can_do.map { |x| normalize(x, @route, :successful, true) } +
              and_cannot_do.map { |x| normalize(x, @route, fails_with, false) }

    it_behaves_like :permissions_for, {
      route: @route,
      route_params: @route_params,
      user: user,
      actions: actions,
      factory: @factory,
      validate_callback: @validate_callback
    }
    registered_users << user
  end

  def everything
    STANDARD_ACTIONS
  end

  def everything_but_new
    @everything_but_new ||= (STANDARD_ACTIONS - [:new]).freeze
  end

  def nothing
    # new is always accessible to everyone
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

  def listing
    @listing ||= Set[:index, :filter, :new].freeze
  end

  def not_listing
    @not_listing ||= (everything - listing).freeze
  end

  def self.extended(base)
    base.registered_users = Set.new
    base.after(:all) do
      users_not_tested = STANDARD_USERS - base.registered_users

      next if users_not_tested.empty?

      route = base.instance_variable_get(:'@route')
      untested = users_not_tested.to_a.join(', ')
      raise "Some users were not tested by the permissions spec for #{route}. Add tests for the following users: #{untested}"
    end
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
    raise 'route must be set' if @route.nil?
    raise 'route parameters must be set' if @route_params.nil?
    raise 'a factory must be set' if @factory.nil?
    raise 'validate callback must be set' if @validate_callback.nil?
  end

  def validate_sets(user, can_do:, and_cannot_do:)
    message = "The permission spec for the `:#{user}` user"
    # find if there are any overlaps
    intersection = can_do & and_cannot_do
    if intersection.any?
      raise "#{message} has overlapping can and cannot permissions. The following are duplicates: #{intersection}"
    end

    # ensure we've covered all the standard actions
    missing = STANDARD_ACTIONS - (can_do + and_cannot_do)
    raise "#{message} does not cover all standard actions. The following are missing: #{missing}" unless missing.empty?
  end

  def normalize(item, route, expected_status, can)
    result = VERB_LOOKUP[item] if item.is_a?(Symbol) && VERB_LOOKUP.key?(item)

    result = result.dup
    result[:action] = item if item.is_a?(Symbol)
    result[:expected_status] = expected_status unless result.key?(:expected_status)
    result[:can] = can

    validate_action_hash(result, item)

    result[:path] = Addressable::Template.new(route + '/' + result[:path])
    result
  end

  def validate_action_hash(action, item)
    unless [:list, :single, :nothing, :template, :created].include?(action[:expect])
      raise "expect value #{action[:expect]} is not recognized"
    end

    return if action.is_a?(Hash) &&
              action.key?(:path) &&
              action.key?(:verb) &&
              action.key?(:action)

    raise "item `#{item}` is not valid. It must be a standard action symbol or a hash wit they keys :path and :verb and :action and :expect"
  end
end

RSpec.shared_examples :permissions_for do |options|
  create_entire_hierarchy

  @user = options[:user]
  let(:factory) {
    options[:factory]
  }

  let(:headers) {
    token = (options[:user].to_s + '_token').to_sym
    {
      'ACCEPT' => 'application/json',
      'HTTP_AUTHORIZATION' => send(token)
    }
  }

  let(:route_params) {
    # execute the provided block as if it were defined with this let scope
    instance_exec(&options[:route_params])
  }

  let(:validate_callback) {
    options[:validate_callback]
  }

  def send_request(action, headers, route_params, factory)
    verb = action[:verb]
    path = action[:path]
    action = action[:action]
    headers = headers.dup
    url = path.expand(route_params)

    # some endpoints require a valid body is included
    if [:create, :update].include?(action)
      body = body_attributes_for(factory)
      as = :json
    end

    # process is the generic base method for the get, post, put, etc.. methods
    process(verb, url, headers: headers, params: body, as: as)
  end

  def get_expected_list_items(user, action)
    [*instance_exec(user, action, &validate_callback)]
  end

  def validate_result(user, action, expect)
    # parse the result and assert our subject exist
    result = api_result

    case expect
    when :nothing
      expect(result).to be_nil
    when :template
      expect_data_is_hash
    when :created
      expect_data_is_hash_with_any_id
    when :single
      expect_id_matches(route_params[:id])
    when :list
      expect_has_ids(get_expected_list_items(user, action))
    end
  end

  # add metadata so examples can be filtered by user
  context "the `#{options[:user]}` user", { @user => true, :permissions => true } do
    options[:actions].each do |action|
      example_name = "should #{action[:can] ? '' : 'NOT '}be able to #{action[:verb].upcase} #{action[:path].pattern}"
      # again add metadata to allow filtering by action
      example example_name, { action[:action] => true } do
        # first build and issue request
        send_request(action, headers, route_params, factory)

        expected = action[:expected_status]
        expect(response).to have_http_status(expected)

        # only validate results if we expect valid data
        next unless action[:can]

        validate_result(options[:user], action[:action], action[:expect])
      end
    end
  end
end
