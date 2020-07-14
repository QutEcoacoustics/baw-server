# included in rails_helpers.rb
require 'swagger_helper'

module Rswag
  module Specs
    #https://github.com/rswag/rswag/issues/325
    class SwaggerFormatter < ::RSpec::Core::Formatters::BaseTextFormatter
      def upgrade_content!(mime_list, target_node)
        target_node[:content] ||= {} # Here we're avoiding "content" key overriding
        schema = target_node[:schema]
        return if mime_list.empty? || schema.nil?

        mime_list.each do |mime_type|
          # TODO: upgrade to have content-type specific schema
          (target_node[:content][mime_type] ||= {}).merge!(schema: schema)
        end
      end
    end

    module ExampleGroupHelpersPatch
      [:get, :post, :patch, :put, :delete, :head, :options, :trace].each do |verb|
        define_method(verb) do |summary, &block|
          # Patching https://github.com/rswag/rswag/blob/42fdf6d482b2e5d4aee4f461abf697b2aa9c3894/rswag-specs/lib/rswag/specs/example_group_helpers.rb#L78
          # if we have existing operation metadata, then merge it in.
          # We have to patch because this method overwrites anything already there
          existing_operation_metadata = metadata[:operation]
          subclass = super(summary, &block)
          subclass.metadata[:operation].merge!(existing_operation_metadata) unless existing_operation_metadata.nil?
          subclass.metadata[:operation].delete(:consumes) if [:get, :head, :options].include?(verb)
        end
      end
    end

    ExampleGroupHelpers.prepend ExampleGroupHelpersPatch
  end
end

RSpec.shared_context :api_spec_shared_context do
  # after every api test
  after(:each) do |example|
    #puts 'i happened'
    # include the response as an example
    example.metadata[:response][:content] = {
      'application/json' => api_result
    }

    raise 'API specs must have a model set in a `let`' if model.nil?

    # also include additional tags to describe permissions
    tags = example.metadata[:operation][:tags]
    tags = [tags] unless tags.is_a? Array

    # first resolve path to controller and action
    route = Rails.application.routes.recognize_path(request.url, method: request.env['REQUEST_METHOD'])

    # then for all of the test users we know about, see if they have access
    all_users.each do |user|
      abilities = Ability.new(user)
      can = abilities.can? model, route[:action]

      # if they do, add a tag
      user_name = user&.user_name.nil? ? 'anyone' : user.user_name
      tags << "#{user_name} can access" if can
    end

    example.metadata[:operation][:tags] = tags
  end

  before(:each) do |example|
    #    puts example.metadata
  end
end

# config.extend allows these methods to be used in describe/groups
module ApiSpecDescribeHelpers
  def self.extended(base)
    raise ':operation should not be defined yet' unless base.metadata[:operation].nil?

    base.metadata[:operation] = {}
  end

  def with_authorization
    # these tests document an API - they're not really for testing user access
    # Even if they were, the OAS specification has no concept of different
    # responses based on user roles. So all documentation tests are done under
    # the admin user.
    #
    # Actual auth tests should be done in the requests specs.
    #
    # NOTE: rswag won't use the let `Authorization` unless there is a
    # basic auth section defined in components/securitySchemes in swagger_helper!
    security [basic_auth_with_token: []]
    let(:Authorization) { admin_token }
  end

  def with_query_string_authorization
    # see notes in with_authorization about token
    security [auth_token_query_string: []]
    let(:auth_token) { admin_token }
  end

  def sends_json_and_expects_json
    #let('Accept') { 'application/json; charset=utf-8' }
    #let('Content-type') { 'application/json' }
    produces 'application/json'
    consumes 'application/json'
  end

  def for_model(given_model)
    @@group_model = given_model
    let(:model) { @@group_model }
  end

  def which_has_schema(&block)
    @@group_model_schema = yield block
    # let(:model_schema) {
    #   @@group_model_schema
    # }
  end

  def body_name
    # rswag expects let statements to be defined with the same name as the parameters,
    # however, our creation scripts already define many let statements that have the
    # same name as our models... so naming the parameter project forces us to overwrite
    # the project let defined in creation.
    # All this wouldn't be so bad except that let statements are dynamically scoped
    # and any redefinition is applied to all uses (it doesn't just hide the parent for
    # the current lexical scope!)
    @@body_name ||= (@@group_model.model_name.singular + '_attributes').to_sym
  end

  def model_sent_as_parameter_in_body
    parameter name: body_name, in: :body, schema: @@group_model_schema
  end

  def send_model(&block)
    let(body_name, &block)
  end

  def schema_for_single
    schema allOf: [
      { '$ref' => '#/components/schemas/standard_response' },
      {
        type: 'object',
        properties: {
          data: @@group_model_schema
        }
      }
    ]
  end

  def schema_for_many
    schema allOf: [
      { '$ref' => '#/components/schemas/standard_response' },
      {
        type: 'object',
        properties: {
          data: {
            type: 'array',
            items: @@group_model_schema
          }
        }
      }
    ]
  end
end

# config.include allows these methods to be used in specs/before/let
module ApiSpecExampleHelpers
  def api_result
    @api_result ||= response&.body&.empty? ? nil : JSON.parse(response.body, symbolize_names: true, object_class: OpenStruct)
  end

  def assert_id_matches(expected)
    expect(api_result.data.id).to be(expected.id)
  end

  def assert_has_ids(*expected)
    expected_ids = expected.map { |e| e.id }
    actual_ids = api_result.data.map { |a| a.id }
    expect(actual_ids).to contain(expected_ids)
  end

  def assert_at_least_one_item
    api_result.data.should have_at_least(1).items
  end

  def assert_no_response
    expect(response.body).to be_empty
  end

  def self.included(base); end
end
