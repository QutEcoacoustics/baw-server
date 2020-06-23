# frozen_string_literal: true

require 'rails_helper'

describe ApplicationController, type: :controller do
  describe 'Application wide tests' do
    controller do
      skip_authorization_check

      def index
        response.headers['Content-Length'] = -100
        render(text: 'test response')
      end
    end

    it 'it fails if content-length is negative' do
      expect {
        get :index
      }.to raise_error(CustomErrors::BadHeaderError)
    end
  end

  describe 'sanitize_associative_array', type: :controller do
    let!(:field_name) { 'field_name' }
    let!(:controller) { ApplicationController.new }

    describe 'string inputs' do
      it 'should handle empty string' do
        expect {
          controller.instance_eval { sanitize_associative_array('', :field_name) }
        }.to raise_error(CustomErrors::NotAcceptableError)
      end

      it 'should handle single quotes' do
        expect {
          controller.instance_eval { sanitize_associative_array('\'\'', :field_name) }
        }.to raise_error(CustomErrors::NotAcceptableError)
      end

      it 'should handle double quotes' do
        expect {
          controller.instance_eval { sanitize_associative_array('""', :field_name) }
        }.to raise_error(CustomErrors::NotAcceptableError)
      end

      it 'should handle invalid stringified object' do
        expect {
          controller.instance_eval { sanitize_associative_array('{123:123}', :field_name) }
        }.to raise_error(CustomErrors::NotAcceptableError)
      end

      it 'should handle stringified array' do
        expect {
          controller.instance_eval { sanitize_associative_array('[1,2,3]', :field_name) }
        }.to raise_error(CustomErrors::BadRequestError)
      end
    end

    describe 'scalar inputs' do
      it 'should handle nil input' do
        expect(
          controller.instance_eval { sanitize_associative_array(nil, :field_name) }
        ).to be_nil
      end

      it 'should handle number' do
        expect {
          controller.instance_eval { sanitize_associative_array(42, :field_name) }
        }.to raise_error(CustomErrors::BadRequestError)
      end

      it 'should handle boolean' do
        expect {
          controller.instance_eval { sanitize_associative_array(true, :field_name) }
        }.to raise_error(CustomErrors::BadRequestError)
      end
    end

    describe 'non-scalar inputs' do

      it 'should handle empty object' do
        expect(
          controller.instance_eval { sanitize_associative_array({}, :field_name) }
        ).to include({})
      end

      it 'should handle object' do
        expect(
          controller.instance_eval { sanitize_associative_array({ 'test': 'value' }, :field_name) }
        ).to include('test': 'value')
      end

      it 'should handle array' do
        expect {
          controller.instance_eval { sanitize_associative_array([1, 2, 3], :field_name) }
        }.to raise_error(CustomErrors::BadRequestError)
      end

    end

    describe 'error messages' do
      it 'should return not acceptable error' do
        expect {
          controller.instance_eval { sanitize_associative_array('', 'custom_field') }
        }.to raise_error(CustomErrors::NotAcceptableError).with_message(/custom_field/)
      end

      it 'should return bad request error' do
        expect {
          controller.instance_eval { sanitize_associative_array([1, 2, 3], 'custom_field') }
        }.to raise_error(CustomErrors::BadRequestError).with_message(/custom_field/)
      end
    end
  end
end
