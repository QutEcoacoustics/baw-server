require 'rails_helper'

describe ApplicationController, { type: :controller } do
  controller do
    skip_authorization_check

    def index
      response.headers['Content-Length'] = -100
      render({ text: 'test response' })
    end
  end

  describe 'Application wide tests' do
    it 'it fails if content-length is negative' do
      expect {
        get :index
      }.to raise_error(CustomErrors::BadHeaderError)
    end
  end
end
