require 'rails_helper'

describe ResponsesController, type: :controller do

  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(200)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get :show, {:id => 1}
      expect(response).to have_http_status(404)
    end
  end

  describe "GET #filter" do
    it "returns http success" do
      get :filter
      expect(response).to have_http_status(200)
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
      post :create, { :study_id => 1 }
      expect(response).to have_http_status(401)
    end
  end

end
