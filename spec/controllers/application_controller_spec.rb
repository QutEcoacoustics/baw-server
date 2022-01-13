# frozen_string_literal: true

describe ApplicationController, type: :controller do
  describe 'Application wide tests' do
    controller do
      skip_authorization_check

      def index
        response.headers['Content-Length'] = -100
        render(text: 'test response')
      end
    end

    it 'fails if content-length is negative' do
      expect {
        get :index
      }.to raise_error(CustomErrors::BadHeaderError)
    end
  end

  describe 'associative array validation', type: :controller do
    controller do
      skip_authorization_check
      skip_load_and_authorize_resource

      def index
        sanitize_associative_array(:some_field)
        cleaned = params.slice(:some_field).permit(some_field: {}).to_h

        respond cleaned
      end

      def nested
        sanitize_associative_array(:nested, :some_field)
        cleaned = params.require(:nested).permit(some_field: {}).to_h

        respond cleaned
      end

      private

      def respond(result)
        render json: result, status: :created, layout: false
      end
    end

    before do
      routes.draw do
        post 'nested' => 'anonymous#nested'
        post 'index' => 'anonymous#index'
      end
    end

    def error_response(error_message = :root_hash)
      case error_message
      when :valid_json
        status = 400
        message = 'Bad Request'
        details = 'The request was not valid: some_field is not valid JSON. Additionally, support for string-encoded JSON is deprecated.'
      when :root_hash
        status = 422
        message = 'Unprocessable Entity'
        details = 'The request could not be understood: some_field must have a root JSON object (not a scalar or an array).'
      end
      {
        'meta' =>
        {
          'error' =>
          {
            'details' => details,
            'info' => nil
          },
          'message' => message,
          'status' => status
        }
      }
    end

    shared_examples_for 'sanitization', :aggregate_failures do |current_action|
      let(:current_action) { current_action }

      def invoke(test_value, expected = :unprocessable_entity)
        body = current_action == :nested ? { nested: { some_field: test_value } } : { some_field: test_value }
        post current_action, body: body.to_json, as: :json, format: :json
        #post current_action, body: body.to_json, format: :json
        expect(response.media_type).to include('application/json')
        expect(response).to have_http_status(expected)

        JSON.parse(response.body)
      end

      describe 'should parse strings as JSON,' do
        it 'but reject an empty string' do
          expect(
            invoke('', :bad_request)
          ).to include(error_response(:valid_json))
        end

        it 'but reject single quotes' do
          expect(
            invoke('\'\'', :bad_request)
          ).to include(error_response(:valid_json))
        end

        it 'but reject double quotes' do
          expect(
            invoke('""')
          ).to include(error_response)
        end

        it 'but reject invalid json' do
          expect(
            invoke('{123:123}', :bad_request)
          ).to include(error_response(:valid_json))
        end

        it 'but reject an array' do
          expect(
            invoke('[1,2,3]')
          ).to include(error_response)
        end

        it 'and accept an empty object' do
          expect(
            invoke('{}', :created)
          ).to include({ 'some_field' => {} })
        end

        it 'and accept an object' do
          expect(
            invoke('{ "test": "value" }', :created)
          ).to include({ 'some_field' => { 'test' => 'value' } })
        end
      end

      describe 'scalar inputs are' do
        it 'converted when null' do
          expect(
            invoke(nil, :created)
          ).to include({ 'some_field' => {} })
        end

        it 'rejected when a number' do
          expect(
            invoke(42)
          ).to include(error_response)
        end

        it 'rejected when a boolean' do
          expect(
            invoke(true)
          ).to include(error_response)
        end
      end

      describe 'for non-scalar inputs it will' do
        it 'accept an empty object' do
          expect(
            invoke({}, :created)
          ).to include({ 'some_field' => {} })
        end

        it 'accept an object' do
          expect(
            invoke({ 'test' => 'value' }, :created)
          ).to include({ 'some_field' => { 'test' => 'value' } })
        end

        it 'preserve raw literals in an object' do
          expect(
            invoke({ 'test' => 'value', 'test2' => 3, 'test4' => true }, :created)
          ).to include({ 'some_field' => { 'test' => 'value', 'test2' => 3, 'test4' => true } })
        end

        it 'reject an array' do
          expect(
            invoke([1, 2, 3])
          ).to include(error_response)
        end
      end
    end

    describe 'for root values,' do
      it_behaves_like 'sanitization', :index
    end

    describe 'for nested values,' do
      it_behaves_like 'sanitization', :nested
    end
  end

  describe 'Current' do
    create_entire_hierarchy

    controller(ApplicationController) do
      skip_authorization_check

      def index_ability
        render plain: Current.ability&.class&.name
      end

      def index_user
        render(plain: Current.user&.user_name)
      end
    end

    before do
      routes.draw do
        get 'index_user' => 'anonymous#index_user'
        get 'index_ability' => 'anonymous#index_ability'
      end

      project.allow_original_download = :reader
      project.save!
    end

    it 'inherits from the application controller' do
      expect(controller).to be_a_kind_of(ApplicationController)
    end

    it 'sets Current.user when a user session is supplied' do
      request.env['HTTP_AUTHORIZATION'] = reader_token
      response = get :index_user
      expect(Current.user).to eq reader_user
      expect(response.body).to eq(reader_user.user_name)
    end

    it 'sets Current.user to nil when there is no user session' do
      response = get :index_user
      expect(Current.user).to be_nil
      expect(response.body).to eq('')
    end

    it 'sets Current.ability when a user session is supplied' do
      request.env['HTTP_AUTHORIZATION'] = reader_token
      response = get :index_ability
      expect(Current.ability).to be_an_instance_of(Ability)

      # if you're signed in you can download an original recording
      expect(Current.ability.can?(:original, audio_recording)).to eq true

      expect(response.body).to eq('Ability')
    end

    it 'sets Current.ability even when a user session is not supplied' do
      response = get :index_ability
      expect(Current.ability).to be_an_instance_of(Ability)

      # if you're signed in you cannot download an original recording
      expect(Current.ability.can?(:original, audio_recording)).to eq false

      expect(response.body).to eq('Ability')
    end
  end
end
