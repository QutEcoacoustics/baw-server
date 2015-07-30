class AdminController < ApplicationController


  def index
    authorize! :index, :admin
    respond_to do |format|
      format.html
      format.json { no_content_as_json }
    end
  end
end