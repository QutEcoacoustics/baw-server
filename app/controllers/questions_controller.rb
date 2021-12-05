# frozen_string_literal: true

class QuestionsController < ApplicationController
  include Api::ControllerHelper

  #skip_authorization_check

  # GET /questions
  # GET /studies/:study_id/questions
  def index
    do_authorize_class

    query = Question.all

    if params[:study_id]
      # todo:
      # check if this can be done better. We shouln't need to join
      # all the way to study, only to the join table.
      query = query.belonging_to_study(params[:study_id])
    end

    @questions, opts = Settings.api_response.response_advanced(
      api_filter_params,
      query,
      Question,
      Question.filter_settings
    )
    respond_index(opts)
  end

  # GET /questions/:id
  def show
    do_load_resource
    do_authorize_instance
    respond_show
  end

  # GET /questions/filter
  def filter
    do_authorize_class

    filter_response, opts = Settings.api_response.response_advanced(
      api_filter_params,
      Question.all,
      Question,
      Question.filter_settings
    )
    respond_filter(filter_response, opts)
  end

  # GET /questions/new
  def new
    do_new_resource
    do_set_attributes
    do_authorize_instance
    respond_new
  end

  # POST /questions
  def create
    do_new_resource
    do_set_attributes(question_params)
    do_authorize_instance

    if @question.save
      respond_create_success(question_path(@question))
    else
      respond_change_fail
    end
  end

  # PUT /questions/:id
  def update
    do_load_resource
    do_authorize_instance

    if @question.update(question_params)
      respond_show
    else
      respond_change_fail
    end
  end

  # DELETE /questions/:id
  def destroy
    do_load_resource
    do_authorize_instance
    @question.destroy
    respond_destroy
  end

  private

  def question_params
    # empty array is replaced with nil by rails. Revert to empty array
    # to avoid errors with strong parameters
    # https://github.com/rails/rails/issues/13766
    # TODO: remove, fixed in https://github.com/rails/rails/pull/16924 (rails 5.1)
    if params.key?(:question) && params[:question].key?(:study_ids) && params[:question][:study_ids].nil?
      params[:question][:study_ids] = []
    end
    permitted = [{ study_ids: [] }, :text, :data]
    params.require(:question).permit(permitted)
  end
end
