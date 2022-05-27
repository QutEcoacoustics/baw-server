# frozen_string_literal: true

RSpec.shared_examples 'permissions for' do |options|
  @user = options[:user]
  let(:request_body_options) {
    options[:request_body_options]
  }

  let(:headers) {
    token = "#{options[:user]}_token".to_sym
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

  def get_body(action, request_body_options)
    case action
    when :create
      instance_exec(&request_body_options[:create])
    when :update
      instance_exec(&request_body_options[:update])
    else
      [nil, nil]
    end
  end

  def send_request(action, headers, route_params, request_body_options)
    verb = action[:verb]
    path = action[:path]
    action = action[:action]
    url = path.expand(route_params)

    # some endpoints require a valid body is included
    body, as = get_body(action, request_body_options)

    # process is the generic base method for the get, post, put, etc.. methods
    process(verb, url, headers: headers, params: body, as: as)
  end

  def get_expected_list_items(user, action)
    raise 'validate callback must be set' if expected_list_items_callback.nil?

    Array(instance_exec(user, action, &expected_list_items_callback))
  end

  def validate_result(user, action, expect)
    case expect
    when :nothing
      expect(api_result).to be_nil
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
  context "the `#{options[:user]}` user", { @user => true, :permissions => true } do
    options[:actions].each do |action|
      example_name = "should #{action[:can] ? '' : 'NOT '}be able to #{action[:verb].upcase} #{action[:path].pattern}"
      # again add metadata to allow filtering by action
      example example_name, { action[:action] => true } do
        # first build and issue request
        send_request(action, headers, route_params, request_body_options)

        aggregate_failures 'Failures:' do
          expected = action[:expected_status]
          expect(response).to have_http_status(expected)

          # only validate results if we expect valid data
          validate_result(options[:user], action[:action], action[:expect]) if action[:can]
        end
      end
    end
  end
end
