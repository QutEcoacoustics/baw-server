class PublicController < ApplicationController
  def index
    respond_to do |format|
      format.html {
        if user_signed_in?
          accessible_projects = current_user.recently_updated_projects
          @projects = accessible_projects.limit(3)

        else
          @projects = Project.none
        end
      }
      format.json { no_content_as_json }
    end
  end
end