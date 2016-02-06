module Admin
  class HomeController < BaseController

    # GET /admin
    def index
      respond_to do |format|
        format.html
      end
    end

  end
end