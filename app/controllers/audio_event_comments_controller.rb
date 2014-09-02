class AudioEventCommentsController < ApplicationController

  load_and_authorize_resource :audio_event
  load_and_authorize_resource :audio_event_comment, through: :audio_event, through_association: :comments
  respond_to :json

  # GET /audio_event_comments
  # GET /audio_event_comments.json
  def index
    #@audio_event_comments = AudioEventComment.accessible_by

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @audio_event_comments }
    end
  end

  # GET /audio_event_comments/1
  # GET /audio_event_comments/1.json
  def show
    #@audio_event_comment = AudioEventComment.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @audio_event_comment }
    end
  end

  # GET /audio_event_comments/new
  # GET /audio_event_comments/new.json
  def new
    #@audio_event_comment = AudioEventComment.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @audio_event_comment }
    end
  end

  # POST /audio_event_comments
  # POST /audio_event_comments.json
  def create
    #@audio_event_comment = AudioEventComment.new(params[:audio_event_comment])

    respond_to do |format|
      if @audio_event_comment.save
        format.html { redirect_to @audio_event_comment, notice: 'Audio event comment was successfully created.' }
        format.json { render json: @audio_event_comment, status: :created, location: @audio_event_comment }
      else
        format.html { render action: "new" }
        format.json { render json: @audio_event_comment.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /audio_event_comments/1
  # PUT /audio_event_comments/1.json
  def update
    #@audio_event_comment = AudioEventComment.find(params[:id])

    respond_to do |format|
      if @audio_event_comment.update_attributes(params[:audio_event_comment])
        format.html { redirect_to @audio_event_comment, notice: 'Audio event comment was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @audio_event_comment.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /audio_event_comments/1
  # DELETE /audio_event_comments/1.json
  def destroy
    #@audio_event_comment = AudioEventComment.find(params[:id])
    @audio_event_comment.destroy

    respond_to do |format|
      format.html { redirect_to audio_event_comments_url }
      format.json { head :no_content }
    end
  end
end
