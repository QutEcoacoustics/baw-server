class ErrorsController < ApplicationController

  skip_authorization_check only: [:routing]

  # see exceptions_controller for error handling for correct route but incorrect id.
  def routing
    respond_to do |format|
      format.html { render template: 'errors/routing', status: :not_found }
      format.json { render json: {code: 404, phrase: 'Not Found', message: 'No matches'}, status: :not_found }
    end
  end
end