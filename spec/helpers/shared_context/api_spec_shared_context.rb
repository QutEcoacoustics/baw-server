# frozen_string_literal: true
require "securerandom"

RSpec.shared_context 'with api shared context' do
  # ensure uuid generation is stable
  #using InsecureRandom

  around do |example|
    # need to freeze time so that docs generation does not produce different
    # output every time it's run. This affects timestamps in particular.
    original_tz = ::Time.zone
    Zonebie.backend.zone = ::ActiveSupport::TimeZone['UTC']
    Timecop.freeze(Time.local(2020, 1, 2, 3, 4, 5.678))
    SecureRandom.singleton_class.send(:alias_method, :old_gen_random, :gen_random)
    SecureRandom.send(:define_singleton_method,:gen_random) do |n|
      n = n ? n.to_int : 16
      Array.new(n) { Kernel.rand(256) }.pack('C*')
    end

    example.run

    SecureRandom.singleton_class.send(:alias_method, :gen_random, :old_gen_random)
    Timecop.return
    Zonebie.backend.zone = original_tz
  end

  before do
    # need to freeze time so that docs generation does not produce different
    # output every time it's run. This affects timestamps in particular.
    Timecop.freeze(Time.local(2020, 1, 2, 3, 4, 5.678))
  end

  after do
    Timecop.return
  end

  def json_example
    {
      'application/json' => {
        example: api_result
      }
    }
  end

  def raw_example
    {
      response.content_type => {
        example: response_body
      }
    }
  end

  def add_example(spec_example)
    case response&.content_type
    when %r{.*application/json.*}
      spec_example.metadata[:response][:content] = json_example
    when %r{text/plain}
      spec_example.metadata[:response][:content] = raw_example
    else
      # add no example
      logger.debug("Not adding response example for #{response.content_type}")

    end
  end

  # after every api test
  after do |example|
    # include the response as an example
    add_example(example)

    next if defined?(skip_automatic_description) && skip_automatic_description
    raise 'API specs must have a model set in a `let`' if model.nil?

    # if a test failed, don't proceed with the following
    next if request.nil?

    # also include additional tags
    example.metadata[:operation][:tags] ||= []
    example.metadata[:operation][:tags] << model.model_name.plural

    # also include information about route access
    # first resolve path to controller and action
    route = Rails.application.routes.recognize_path(request.url, method: request.env['REQUEST_METHOD'])

    # then for all of the test users we know about, see if they have access
    can, cannot = all_users.partition { |user|
      abilities = Ability.new(user)
      abilities.can? route[:action].to_sym, model
    }
    user_name = ->(user) { "`#{user&.user_name.nil? ? 'anyone' : user.user_name}`" }

    description = example.metadata[:operation][:description]
    description = <<~MARKDOWN
      #{description.nil? ? '' : description}
      Users that can invoke this route: #{can.map(&user_name).join(', ')}.<br />
      Users that can't: #{cannot.map(&user_name).join(', ')}.

      Note: accessing a list/index/filter endpoint may return no results due to project permissions
    MARKDOWN
    example.metadata[:operation][:description] = description
  end
end
