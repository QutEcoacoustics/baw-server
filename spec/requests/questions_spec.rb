require 'rails_helper'
require 'rspec/mocks'




def question_url(question_id = nil, study_id = nil)

  url = "/questions"
  url = url + "/" + question_id.to_s if question_id
  url = "/studies/#{study_id.to_s}" + url if study_id
  return url

end


describe "Questions" do
  create_entire_hierarchy
  create_study_hierarchy

  # create a bunch of studies, questions and responses to work with
  create_many_studies

  let(:question_attributes) {
    FactoryGirl.attributes_for(:question)
  }

  let(:update_question_attributes) {
    {text: ("updated question text") }
  }

  before(:each) do
    @env ||= {}
    @env['HTTP_AUTHORIZATION'] = admin_token
    @env['CONTENT_TYPE'] = "application/json"
  end

  describe 'index,filter,show questions' do

    describe 'index' do

      it 'finds all (1) questions as admin' do
        get question_url, nil, @env
        expect(response).to have_http_status(200)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(1)
        expect(parsed_response['data'][0]['text']).to eq(question['text'])
      end

      it 'finds all (1) questions for the given study as admin' do
        get question_url(nil, study.id), nil, @env
        expect(response).to have_http_status(200)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(1)
        expect(parsed_response['data'][0]['text']).to eq(question['text'])
      end

      it 'finds the correct questions for the given study as admin' do

        available_records = many_studies

        study_id = available_records[:studies][0].id
        get question_url(nil, study_id), nil, @env
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(available_records[:studies][0].question_ids.count)
        expect((parsed_response['data'].map { |q| q['id']  }).sort).to eq(available_records[:studies][0].question_ids.sort)

        study_id = available_records[:studies][1].id
        get question_url(nil, study_id), nil, @env
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(available_records[:studies][1].question_ids.count)
        expect((parsed_response['data'].map { |q| q['id']  }).sort).to eq(available_records[:studies][1].question_ids.sort)

      end

    end

    describe 'filter' do

      it 'finds all (1) questions as admin' do
        get question_url + "/filter", nil, @env
        expect(response).to have_http_status(200)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(1)
        expect(parsed_response['data'][0]['text']).to eq(question['text'])
      end

      it 'finds the correct questions for the given study as admin' do

        available_records = many_studies

        url = question_url + "/filter"

        study = available_records[:studies][0]
        # there might be a more efficient way to do this query, without
        # joining all the way to studies.
        filter_params = { filter: { 'studies.id'=> {in: [study.id] } }}
        post url, filter_params.to_json, @env
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].count).to eq(available_records[:studies][0].question_ids.count)
        expect((parsed_response['data'].map { |q| q['id']  }).sort).to eq(available_records[:studies][0].question_ids.sort)

      end

    end

    describe 'show' do

      it 'show question as admin' do
        get question_url(question.id), nil, @env
        expect(response).to have_http_status(200)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['data'].to_json).to eq(question.to_json)
      end

    end

  end

  describe 'create and update' do

    describe 'create question' do

      it 'creates an orphan question' do
        post question_url, question_attributes.to_json, @env
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(201)
        expect(parsed_response['data'].symbolize_keys.slice(:text, :data)).to eq(question_attributes)
        expect(parsed_response['data'].keys.sort).to eq(%w(id creator_id updater_id text
                                                        data created_at updated_at).sort)
        expect(Question.all.count).to eq(2)
      end

      it 'creates an question for a study' do
        params = { question: question_attributes }
        params[:question][:study_ids] = [study.id]
        post question_url, params.to_json, @env
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(201)
        expect(parsed_response['data'].symbolize_keys.slice(:text, :data)).to eq(question_attributes.slice(:text, :data))
        expect(parsed_response['data'].keys.sort).to eq(%w(id creator_id updater_id text
                                                        data created_at updated_at).sort)
        expect(Question.all.count).to eq(2)
        # check that the newly created question is associated with exactly one study
        # and that the associated study has the correct id
        joined_active_record = Question.where(id: parsed_response['data']['id']).includes(:studies)[0]
        expect(joined_active_record.studies.count).to eq(1)
        expect(joined_active_record.studies.first.id).to eq(study.id)
      end

    end

    describe 'update question' do

      it 'updates a question' do
        params = {question: {text: 'modified question text'}}.to_json
        put question_url(question.id), params, @env
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(200)
        expect(parsed_response['data']['text']).to eq('modified question text')
      end

      it 'adds an existing question to an existing study' do

        available_records = many_studies
        # find an existing question that is not already associated with all studies
        existing_question = (available_records[:questions].select {
            |s| s.studies.length < available_records[:studies].length
        })[0]
        # find an existing study id that is not already associated with the question
        available_study_ids = available_records[:studies].map(&:id) - existing_question.study_ids
        study_id_to_add = available_study_ids[0]

        study_ids = existing_question.study_ids
        study_ids.push(study_id_to_add)

        # adding a question to a study requires updating either the question or the study record with
        # all the associated ids including the new one.
        params = {question: {study_ids: study_ids}}.to_json

        put question_url(existing_question.id), params, @env
        #parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(200)
        expect(Question.find(existing_question.id).study_ids.sort).to eq(study_ids.sort)

      end

      it 'does not allow a question with no studies' do

        # doesn't work because require/permit fails with study_ids = nil

        params = {question: {study_ids: []}}.to_json
        put question_url(question.id), params, @env
        parsed_response = JSON.parse(response.body)
        expect(response).to have_http_status(415)

      end


    end

  end

  describe 'delete' do

    it 'deletes a question and child responses' do

      delete question_url(question.id), nil, @env
      expect(response).to have_http_status(204)
      expect(Question.all.count).to eq(0)
      expect(Response.all.count).to eq(0)

    end

  end

end



