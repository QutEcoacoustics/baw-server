class BookmarksController < ApplicationController

  load_resource :audio_recording, only: [:new, :create]
  load_and_authorize_resource :bookmark
  respond_to :json

  # GET /bookmarks
  # GET /bookmarks.json
  def index

    cleaned_params = CleanParams.perform(params)

    query = Bookmark.scoped

    unless params[:name].blank?
      query = query.merge(Bookmark.filter_by_name(cleaned_params[:name]))
    end

    unless params[:category].blank?
      query = query.merge(Bookmark.filter_by_category(cleaned_params[:category]))
    end

    @bookmarks = query
    #@bookmarks = [{hi: 'hello', boring: :yes}, {hi: 4565, boring: :yes}]

    respond_to do |format|
      format.html # index.html.erb
      format.json # index.json.jbuilder
    end
  end

  # GET /bookmarks/1
  # GET /bookmarks/1.json
  def show
    @bookmark = Bookmark.where(id: params[:id]).first

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @bookmark }
    end
  end

  # GET /bookmarks/new
  # GET /bookmarks/new.json
  def new
    @bookmark = Bookmark.new
    @bookmark.audio_recording = @audio_recording

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @bookmark }
    end
  end

  # GET /bookmarks/1/edit
  def edit
    @bookmark = Bookmark.where(id: params[:id]).first
  end

  # POST /bookmarks
  # POST /bookmarks.json
  def create
    @bookmark = Bookmark.new(params[:bookmark])
    @bookmark.audio_recording = @audio_recording

    respond_to do |format|
      if @bookmark.save
        format.html { redirect_to @bookmark, notice: 'Bookmark was successfully created.' }
        format.json { render json: @bookmark, status: :created, location: @bookmark }
      else
        format.html { render action: "new" }
        format.json { render json: @bookmark.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /bookmarks/1
  # PUT /bookmarks/1.json
  def update
    @bookmark = Bookmark.where(id: params[:id]).first

    respond_to do |format|
      if @bookmark.update_attributes(params[:bookmark])
        format.html { redirect_to @bookmark, notice: 'Bookmark was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @bookmark.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /bookmarks/1
  # DELETE /bookmarks/1.json
  def destroy
    @bookmark = Bookmark.where(id: params[:id]).first
    @bookmark.destroy

    respond_to do |format|
      format.html { redirect_to bookmarks_url }
      format.json { head :no_content }
    end
  end
end
