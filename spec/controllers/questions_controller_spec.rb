require 'rails_helper'

describe QuestionsController, type: :controller do

  # before {
  #   allow(CanCan::ControllerResource).to receive(:load_and_authorize_resource){ nil }
  # }

  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(401)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get :show, { :id => 1}
      expect(response).to have_http_status(404)
    end
  end

  describe "GET #filter" do
    it "returns http success" do
      get :filter
      expect(response).to have_http_status(401)
    end
  end

  describe "GET #new" do
    it "returns http success" do
      get :new
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    it "returns http success" do
      # is this how it is done for HABTM associations?
      post :create, { :study_ids => [1] }
      expect(response).to have_http_status(404)
    end
  end

  describe "PUT #update" do
    it "returns http success" do
      put :update, { :id => 1, :data => "something" }
      expect(response).to have_http_status(404)
    end
  end

end
