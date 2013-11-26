class ListenController < ApplicationController
  def show
    respond_to do |format|
      format.html { render :file => "#{Rails.root}/public/system/listen_to/index.html", :layout => false}
    end
  end
end