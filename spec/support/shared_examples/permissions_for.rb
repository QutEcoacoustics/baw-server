# frozen_string_literal: true

RSpec.shared_examples 'permissions for' do |options|
  @user = options[:user]
  let(:request_body_options) {
    options[:request_body_options]
  }

  let(:headers) {
    token = :"#{options[:user]}_token"
    {
      'ACCEPT' => defined?(request_accept) ? request_accept : 'application/json',
      'HTTP_AUTHORIZATION' => send(token)
    }
  }

  let(:route_params) {
    # execute the provided block as if it were defined with this let scope
    instance_exec(&options[:route_params])
  }

  let(:update_attrs_subset) {
    options[:update_attrs_subset]
  }

  let(:expected_list_items_callback) {
    options[:expected_list_items_callback]
  }

  let(:before_request_callback) {
    options[:before_request_callback]
  }

  def before_request_do(user, action, other_callback)
    instance_exec(user, action, &before_request_callback) if before_request_callback.present?

    return if other_callback.blank?

    instance_exec(user, action, &other_callback)
  end

  def get_body(body_key, request_body_options)
    case body_key
    in Proc
      instance_exec(&body_key)
    in [body, as]
      [body, as]
    in :create
      instance_exec(&request_body_options[:create])
    in :update
      instance_exec(&request_body_options[:update])
    else
      [nil, nil]
    end
  end

  def send_permissions_request(action, headers, route_params, request_body_options)
    verb = action[:verb]
    path = action[:path]
    body_key = action[:body]

    url = path.expand(route_params).to_s

    # some endpoints require a valid body is included
    body, as = get_body(body_key, request_body_options)

    # process is the generic base method for the get, post, put, etc.. methods

    process(verb, url, headers:, params: body, as:)
  end

  def get_expected_list_items(user, action)
    raise 'validate callback must be set' if expected_list_items_callback.nil?

    Array(instance_exec(user, action, &expected_list_items_callback))
  end

  def validate_permissions_result(user, action, expect)
    case expect
    when :nothing
      expect(api_result).to be_nil
    # template is our name for a /new response and we just check a hash is emitted
    when :template
      expect_data_is_hash
    when :created
      expect_data_is_hash_with_any_id
    when :single
      expect_id_matches(route_params[:id])
    when :list
      expect_has_ids(get_expected_list_items(user, action))
    when is_a?(Proc)
      instance_exec(user, action, &expect)
    end
  end

  # add metadata so examples can be filtered by user
  context "the `#{options[:user]}` user", :permissions, { @user => true } do
    options[:actions].each do |action|
      example_name = "should #{action[:can] ? '   ' : 'NOT'} be able to #{action[:verb].upcase} #{action[:path].pattern} (#{action[:action]})"

      # again add metadata to allow filtering by action
      it example_name, { action[:action] => true } do
        # allow a hook for modifying the subject before the request is sent
        before_request_do(options[:user], action[:action], action[:before])

        # first build and issue request
        send_permissions_request(action, headers, route_params, request_body_options)

        aggregate_failures 'Failures:' do
          expected = action[:expected_status]
          if expected.is_a?(Array)
            expected => [first, *rest]

            rest
              .reduce(have_http_status(first)) do |a, b|
              a.or(have_http_status(b))
            end => assertion
            expect(response).to assertion
          else
            expect(response).to have_http_status(expected)
          end

          # only validate results if we expect valid data
          validate_permissions_result(options[:user], action[:action], action[:expect]) if action[:can]
        end
      end
    end
  end
end
