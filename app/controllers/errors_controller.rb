class ErrorsController < ApplicationController

  skip_authorization_check only: [:routing]

  # see application_controller for error handling for correct route but incorrect id.
  def routing
    respond_to do |format|
      format.html  { render :template => 'errors/routing', locals: {message: 'No route matches'} , status: :not_found }
      format.json  { render :json => {error: '404 Not Found', message: 'No route matches'}, status: :not_found }
    end
  end
end