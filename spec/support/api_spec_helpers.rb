# frozen_string_literal: true

# included in rails_helpers.rb
require 'swagger_helper'

require 'rswag/specs'
# load 'rswag/specs/swagger_formatter'
# module Rswag
#   module Specs
#     #https://github.com/rswag/rswag/issues/325
#     module PatchedSwaggerFormatter
#       def upgrade_content!(mime_list, target_node)
#         target_node[:content] ||= {} # Here we're avoiding "content" key overriding
#         schema = target_node[:schema]
#         return if mime_list.empty? || schema.nil?

#         mime_list.each do |mime_type|
#           # TODO: upgrade to have content-type specific schema
#           (target_node[:content][mime_type] ||= {}).merge!(schema: schema)
#         end
#       end
#     end
#   end
# end

# Rswag::Specs::SwaggerFormatter.prepend Rswag::Specs::PatchedSwaggerFormatter

# config.extend allows these methods to be used in describe/groups
module ApiSpecHelpers
  module ExampleGroup
    def self.extended(base); end

    attr_accessor :baw_consumes, :baw_produces, :baw_security, :baw_model_name, :baw_body_name, :baw_model,
      :baw_factory, :baw_factory_args, :baw_model_schema, :baw_route_params, :baw_body_params

    # these tests document an API - they're not really for testing user access
    # Even if they were, the OAS specification has no concept of different
    # responses based on user roles. So all documentation tests are done under
    # the admin user.
    #
    # Actual auth tests should be done in the requests specs.
    def with_authorization
      self.baw_security = [{ auth_token_header: [] }]
      let(:Authorization) {
        admin_token
      }
    end

    def with_cookie
      self.baw_security = [{ cookie: [] }]
      let(:cookie) {
        password = Settings.admin_user.password
        body = { user: { email: admin_user.email, password: } }
        post '/security', params: body, headers: headers(post: true), as: :json
        expect_success
        cookie = response.headers['set-cookie']&.split(';')&.select { |x| x.include?('_baw_session') }&.first

        expect(cookie).not_to be_blank

        cookie
      }
    end

    def with_jwt
      # see notes in with_authorization about token
      self.baw_security = [{ jwt: [] }]
      let(:Authorization) {
        token = Api::Jwt.encode(subject: reader_user.id)
        "Bearer #{token}"
      }
    end

    def with_query_string_authorization
      # see notes in with_authorization about token
      self.baw_security = [{ auth_token_query_string: [] }]
      let(:auth_token) { admin_token }
    end

    def sends_json_and_expects_json
      self.baw_consumes = ['application/json']
      self.baw_produces = ['application/json']
    end

    def for_model(given_model, factory: nil, factory_args: nil, model_name: nil)
      model_name ||= given_model.model_name.element

      self.baw_model_name = baw_model_name = model_name
      self.baw_factory = factory || baw_model_name
      # rswag expects let statements to be defined with the same name as the parameters,
      # however, our creation scripts already define many let statements that have the
      # same name as our models... so naming the parameter project forces us to overwrite
      # the project let defined in creation.
      # All this wouldn't be so bad except that let statements are dynamically scoped
      # and any redefinition is applied to all uses (it doesn't just hide the parent for
      # the current lexical scope!)
      self.baw_body_name = baw_body_name = :"#{baw_model_name}_attributes"

      self.baw_model = given_model

      raise 'factory_args must be a Proc' unless factory_args.nil? || factory_args.is_a?(Proc)

      self.baw_factory_args = factory_args

      let(:model) { given_model }
      let(:model_name) { baw_model_name }
      let(:body_name) { baw_body_name }
      let(:factory) { factory || baw_model_name }
    end

    def resolve_ref(ref)
      swagger_doc = RSpec.configuration.openapi_specs.first[1]
      parts = ref.split('/').slice(1..).map(&:to_sym)
      schema = swagger_doc.dig(*parts)

      raise "Referenced parameter '#{ref}' must be defined" unless schema

      schema
    end

    # all data returned should have the following schema
    # schema can be a hash style JSON-schema fragment
    # or a string ref to the components/schemas section of
    # the root open api document (openapi_specs in code)
    def which_has_schema(schema)
      ref = nil
      if schema.key? '$ref'
        ref =  schema
        schema = resolve_ref(schema['$ref'])
      end

      self.baw_model_schema = (ref.presence || schema)
      let(:model_schema) {
        schema
      }
    end

    def with_id_route_parameter
      self.baw_route_params ||= []
      self.baw_route_params << {
        name: 'id',
        in: :path,
        type: :integer,
        description: 'id',
        required: true
      }
    end

    def with_route_parameter(name, description = name)
      self.baw_route_params ||= []
      self.baw_route_params << {
        name: name.to_s,
        in: :path,
        type: :integer,
        description: description.to_s,
        required: true
      }
    end

    def model_sent_as_parameter_in_body
      self.baw_body_params ||= []
      self.baw_body_params << {
        name: (get_parent_param :baw_body_name),
        in: :body,
        schema: (get_parent_param :baw_model_schema)
      }
    end

    # post or puts the hash as the payload body
    def send_model(&)
      let((get_parent_param :baw_body_name)) do
        body = instance_eval(&)
        unless body.is_a?(Hash) && (body.key?(model_name) || body.key?(model_name.to_sym))
          raise "Body must have one key with model name (#{model_name}) which then contains attributes. Received instead: #{body}"
        end

        body
      end
    end

    # sends the default factory bot model for previously set :model
    # using attributes_for and filtering out readonly properties
    # from the hash, according to the given schema
    def auto_send_model(subset: nil)
      baw_factory_args = get_parent_param :baw_factory_args

      let((get_parent_param :baw_body_name)) do
        factory_args = instance_exec(&baw_factory_args) if baw_factory_args
        body_attributes_for(model_name, factory:, subset:, factory_args:)
      end
    end

    def ref(key)
      { '$ref' => "#/components/schemas/#{key}" }
    end

    def schema_for_single
      schema allOf: [
        { '$ref' => '#/components/schemas/standard_response' },
        {
          type: 'object',
          properties: {
            data: (get_parent_param :baw_model_schema)
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
              items: (get_parent_param :baw_model_schema)
            }
          }
        }
      ]
    end

    # the way rspec creates describe blocks makes each new
    # describe/ExampleGroup its own class.
    # Any metadata we define on an example group is not accessible
    # unless we traverse up this pseudo-inheritance looking for
    # our desired variables
    def get_parent_param(name)
      # out attr_accessor is possibly defined on every example group
      layers = parent_groups.map { |x| x.send(name) }
      # pick the first non-nil value
      layers.compact.first
    end

    def run_test!(&)
      # we're overriding run test because it is easier to insert our custom helper's
      # metadata in the right spots just before we invoke the test

      # remove accept header if we are not sending a body
      verb = metadata[:operation][:verb]
      if metadata[:operation][:consumes].blank? && [:get, :head, :options].exclude?(verb)
        metadata[:operation][:consumes] = get_parent_param :baw_consumes
      end

      metadata[:operation][:produces] = get_parent_param :baw_produces if metadata[:operation][:produces].blank?
      metadata[:operation][:security] = get_parent_param :baw_security
      #baw_model_name = get_parent_param :baw_model_name
      #baw_body_name = get_parent_param :baw_body_name
      #baw_model = get_parent_param :baw_model
      #baw_model_schema = get_parent_param :baw_model_schema
      metadata[:operation][:parameters] ||= []

      baw_body_params = get_parent_param :baw_body_params
      metadata[:operation][:parameters] += baw_body_params if baw_body_params

      baw_route_params = get_parent_param :baw_route_params
      metadata[:operation][:parameters] += baw_route_params if baw_route_params

      # before do |example|
      #   # validate schema is valid
      #   metaschema = JSON::Validator.validator_for_name('http://json-schema.org/draft/schema#').metaschema
      #   JSON::Validator.validate(metaschema, example.metadata[:response][:schema])
      # end

      before do |example|
        submit_request(example.metadata)
      end

      it "returns a #{metadata[:response][:code]} response" do |example|
        assert_response_matches_metadata(example.metadata, &)
        example.instance_exec(response, &) if block_given?
      end

      # after do |example|
      #   # noop
      # end
    end
  end
end
