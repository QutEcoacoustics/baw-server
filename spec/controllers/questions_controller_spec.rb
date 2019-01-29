require 'rails_helper'

describe QuestionsController, type: :controller do

  # before {
  #   allow(CanCan::ControllerResource).to receive(:load_and_authorize_resource){ nil }
  # }

  create_entire_hierarchy

  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(401)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get :show, { :id => question.id}
      expect(response).to have_http_status(401)
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
      # no permissions needed for new
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST #create" do
    it "returns http success" do
      post :create, { :question => { :study_ids => [study.id] }, :format => :json}
      expect(response).to have_http_status(401)
    end
  end

  describe "PUT #update" do
    it "returns http success" do
      put :update, { :id => question.id, :data => "something" }
      expect(response).to have_http_status(401)
    end
  end

end
