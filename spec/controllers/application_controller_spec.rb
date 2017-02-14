require "rails_helper"


RSpec.describe ApplicationController, type: :controller do
  controller do
    skip_authorization_check

    def index
      response.headers[Api::Constants::HTTP_HEADER_CONTENT_LENGTH] = -100
      render text: "test response"
    end
  end

  describe "Application wide tests" do
    it "it fails if content-length is negative" do
      expect {
        get :index
      }.to raise_error(CustomErrors::BadHeaderError)
    end
  end
end