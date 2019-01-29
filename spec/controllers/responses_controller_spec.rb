require 'rails_helper'

describe ResponsesController, type: :controller do

  create_entire_hierarchy

  describe "GET #index" do
    it "returns http success for index" do
      get :index
      expect(response).to have_http_status(401)
    end
  end

  describe "GET #show" do
    it "returns http success" do
      get :show, { id: user_response.id}
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
      expect(response).to have_http_status(200)
    end
  end

  describe "POST #create" do
    it "returns http success" do
      post :create, { response: { study_id: study.id, question_id: question.id, dataset_item_id: dataset_item.id }}
      # post :create
      expect(response).to have_http_status(401)
    end
  end

end
