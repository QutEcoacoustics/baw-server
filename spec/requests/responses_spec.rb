require 'rails_helper'
require 'rspec/mocks'

def response_url(response_id = nil, study_id = nil)

  url = "/responses"
  url = url + "/" + response_id.to_s if response_id
  url = "/studies/#{study_id.to_s}" + url if study_id
  return url

end

describe "responses" do
  create_entire_hierarchy
  create_study_hierarchy

  # create a bunch of studies, questions and responses to work with
  create_many_studies

  # create two cs hierarchies
  create_citizen_science_hierarchies(2)

  let(:response_attributes) {
    FactoryGirl.attributes_for(:response)
  }

  let(:update_response_attributes) {
    {data: {some_key: 'updated response data'}.to_json }
  }

  before(:each) do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token
    @env['CONTENT_TYPE'] = "application/json"
  end

  describe 'index,filter,show responses' do

    describe 'index' do

      it 'finds all (1) responses as admin' do
        get response_url, nil, @env
        expect(response).to have_http_status(200)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(1)
        expect(parsed_response['data'][0]['data']).to eq(user_response['data'])
      end

      it 'finds all (1) responses for the given study as admin' do
        get response_url(nil, study.id), nil, @env
        expect(response).to have_http_status(200)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(1)
        expect(parsed_response['data'][0]['data']).to eq(user_response['data'])
      end

      it 'finds the correct responses for the given study as admin' do

        available_records = many_studies

        # find responses for the first study in many_studies
        study_id = available_records[:studies][0].id
        get response_url(nil, study_id), nil, @env
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(available_records[:studies][0].response_ids.count)
        expect((parsed_response['data'].map { |q| q['id']  }).sort).to eq(available_records[:studies][0].response_ids.sort)

        study_id = available_records[:studies][1].id
        get response_url(nil, study_id), nil, @env
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(available_records[:studies][1].response_ids.count)
        expect((parsed_response['data'].map { |q| q['id']  }).sort).to eq(available_records[:studies][1].response_ids.sort)

      end

    end

    describe 'filter' do

      it 'finds all (1) responses as admin' do
        get response_url + "/filter", nil, @env
        expect(response).to have_http_status(200)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(1)
        expect(parsed_response['data'][0]['data']).to eq(response['data'])
      end

      it 'finds responses to the study0 and study1 using studies.id' do

        available_records = many_studies

        url = response_url + "/filter"

        study0 = available_records[:studies][0]
        study1 = available_records[:studies][1]
        expected_response_ids = (study0.response_ids +  study1.response_ids).uniq
        filter_params  = { filter: { 'studies.id'  => { in: [study0.id, study1.id] }}}
        post url, filter_params.to_json, @env
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(expected_response_ids.count)
        expect((parsed_response['data'].map { |q| q['id']  }).sort).to eq(expected_response_ids.sort)

      end

      it 'finds responses to the study0 and study1 using study_id' do

        available_records = many_studies

        url = response_url + "/filter"

        study0 = available_records[:studies][0]
        study1 = available_records[:studies][1]
        expected_response_ids = (study0.response_ids +  study1.response_ids).uniq
        filter_params  = { filter: { 'study_id'  => { in: [study0.id, study1.id] }}}
        post url, filter_params.to_json, @env
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(expected_response_ids.count)
        expect((parsed_response['data'].map { |q| q['id']  }).sort).to eq(expected_response_ids.sort)

      end


    end

    describe 'show' do

      it 'show response as admin' do
        get response_url(user_response.id), nil, @env
        expect(response).to have_http_status(200)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].to_json).to eq(user_response.to_json)
      end

    end

  end

  describe 'create and update' do

    describe 'create response' do

      it 'creates a response' do
        params = { response: response_attributes }
        params[:response][:study_id] = study.id
        params[:response][:question_id] = question.id
        params[:response][:dataset_item_id] = dataset_item.id

        post response_url, params.to_json, @env
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(201)
        expect(parsed_response['data'].symbolize_keys.slice(*params[:response].keys)).to eq(params[:response])
        expected_keys = params[:response].keys.map(&:to_s) + %w(id creator_id created_at)
        expect(parsed_response['data'].keys.sort).to eq(expected_keys.sort)
        expect(Response.all.count).to eq(2)
      end

      describe 'missing foreign key' do

        it 'cannot create a response with no study' do
          params = { response: response_attributes }
          params[:response][:question_id] = question.id
          params[:response][:dataset_item_id] = dataset_item.id
          post response_url, params.to_json, @env
          expect(response).to have_http_status(422)
          expect(Response.all.count).to eq(1)
        end

        it 'cannot create a response with no dataset_item' do
          params = { response: response_attributes }
          params[:response][:question_id] = question.id
          params[:response][:study_id] = study.id
          post response_url, params.to_json, @env
          expect(response).to have_http_status(422)
          expect(Response.all.count).to eq(1)
        end

        it 'cannot create a response with no question' do
          params = { response: response_attributes }
          params[:response][:dataset_item_id] = dataset_item.id
          params[:response][:study_id] = study.id
          post response_url, params.to_json, @env
          expect(response).to have_http_status(422)
          expect(Response.all.count).to eq(1)
        end

      end

      it 'cannot create a response with no data' do
        params = { response: {} }
        params[:response][:dataset_item_id] = dataset_item.id
        params[:response][:study_id] = study.id
        params[:response][:question_id] = question.id
        post response_url, params.to_json, @env
        expect(response).to have_http_status(422)
        expect(Response.all.count).to eq(1)
      end



      # todo:
      # These checks will slow down writing so removing this would be an option for speeding
      # things up if necessary in the future
      describe 'incompatible dependencies' do

        it 'ensures parent study and question are associated with each other' do

          # elements of citizen_science_hierarchies are not related to each other (except through audio_recording)
          study_id = citizen_science_hierarchies[0][:study].id
          question_id = citizen_science_hierarchies[1][:question].id
          dataset_item_id = citizen_science_hierarchies[0][:dataset_item].id

          params = { response: response_attributes }
          params[:response][:dataset_item_id] = dataset_item_id
          params[:response][:study_id] = study_id
          params[:response][:question_id] = question_id
          count_before = Response.all.count
          post response_url, params.to_json, @env
          expect(response).to have_http_status(422)
          expect(Response.all.count).to eq(count_before)
          parsed_response = JSON.parse(response.body)
          expect(parsed_response['meta']['error']['info']).to eq({"question_id"=>["parent question is not associated with parent study"]})

        end

        it 'ensures parent study dataset item are associated with each other through dataset' do

          study_id = citizen_science_hierarchies[0][:study].id
          question_id = citizen_science_hierarchies[0][:question].id
          dataset_item_id = citizen_science_hierarchies[1][:dataset_item].id

          params = { response: response_attributes }
          params[:response][:dataset_item_id] = dataset_item_id
          params[:response][:study_id] = study_id
          params[:response][:question_id] = question_id
          count_before = Response.all.count
          post response_url, params.to_json, @env
          expect(response).to have_http_status(422)
          expect(Response.all.count).to eq(count_before)
          parsed_response = JSON.parse(response.body)
          expect(parsed_response['meta']['error']['info']).to eq({"dataset_item_id"=>["dataset item and study must belong to the same dataset"]})

        end

      end


    end

    describe 'update response' do

      it 'cannot update a response' do
        # params = {response: {text: 'modified response text'}}.to_json
        # put response_url(response.id), params, @env
        # parsed_response = JSON.parse(response.body)
        # expect(response).to have_http_status(200)
        # expect(parsed_response['data']['text']).to eq('modified response text')
      end

    end

  end

  describe 'delete' do

    it 'deletes a response' do

      delete response_url(response.id), nil, @env
      expect(response).to have_http_status(204)
      expect(Response.all.count).to eq(0)
      expect(Response.all.count).to eq(0)

    end

  end

end



