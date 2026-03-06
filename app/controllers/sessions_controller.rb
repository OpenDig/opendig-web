class SessionsController < ApplicationController
  skip_before_action :check_editing_mode, only: %i[create destroy failure]

  def create
    if user_signed_in?
      redirect_to root_path, notice: 'Already logged in!'
      return
    end

    auth = request.env['omniauth.auth']
    user = User.find_or_create_by(uid: auth['uid'], provider: auth['provider']) do |u|
      u.email = auth['info']['email']
      u.name = auth['info']['name']
      u.role ||= :viewer
    end
    session[:user_id] = user.id
    greeting = user.name ? '' : ". Welcome #{user.name}!"
    redirect_to root_path, notice: "Logged in with #{user.email}" + greeting
  end

  def destroy
    reset_session
    redirect_to root_path, notice: 'Logged out!'
  end

  # This action is just a static page.
  # The action is needed to generate
  # the route for the static login view.
  def login; end

  def failure
    flash[:error] = 'Authentication failed, please try again.'
    redirect_to root_path
  end
end
