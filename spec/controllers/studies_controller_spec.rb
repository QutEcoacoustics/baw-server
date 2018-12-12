require 'rails_helper'

describe StudiesController, type: :controller do

  describe "GET #index" do
    it "returns http success" do
      get :index
      expect(response).to have_http_status(:success)
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
      expect(response).to have_http_status(:success)
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
      post :create, { :dataset_id => 1 }
      expect(response).to have_http_status(401)
    end
  end

  describe "PUT #update" do
    it "returns http success" do
      put :update, { :id => 1, :dataset_id => 1, :name => "something" }
      expect(response).to have_http_status(404)
    end
  end

end
