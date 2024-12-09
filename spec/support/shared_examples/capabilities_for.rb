# frozen_string_literal: true

RSpec.shared_context 'capabilities for' do |options|
  let(:route_params) {
    # execute the provided block as if it were defined with this let scope
    instance_exec(&options[:route_params])
  }

  let(:user_token) {
    # lookup user token, e.g. reader_token, owner_token, ...
    send(:"#{options[:user]}_token")
  }

  def send_request(action, route, route_params)
    verb = action[:verb]
    path = action[:path]
    path = Addressable::Template.new("#{route}/#{path}")
    url = path.expand(route_params)

    # process is the generic base method for the get, post, put, etc.. methods
    process(verb, url.to_s, **api_headers(user_token))
  end

  def validate_result(name, expected_can)
    details = an_instance_of(String).or(be_nil)
    expect_has_capability(name, expected_can, details)
  end

  # add metadata so examples can be filtered
  can_text = case options[:expected_can]
             when true then 'can'
             when false then 'cannot'
             else 'unsure'
             end
  context_name = "#{options[:name]} equivalent to #{can_text}"
  # again add metadata to allow filtering by action
  context context_name, :capabilities, { options[:name] => true } do
    options[:actions].each do |action|
      it "for the `#{options[:user]}` user, #{action}", { options[:user] => true } do
        # first build and issue request
        send_request(action, options[:route], route_params)

        aggregate_failures 'Failures:' do
          expected = options[:expected_can]

          if expected == :unauthorized
            if response.status == 401
              expect_error(:unauthorized, nil)
            else
              expect_error(:forbidden, nil)
            end
          else
            expect_success

            # only validate results if we expect valid data
            validate_result(options[:name], expected)
          end
        end
      end
    end
  end
end
