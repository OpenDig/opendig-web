class SessionsController < ApplicationController
  def create
    if user_signed_in?
      redirect_to root_path, notice: "Already logged in!"
      return
    end

    auth = request.env['omniauth.auth']
    user = User.find_or_create_by(uid: auth['uid'], provider: auth['provider']) do |u|
      u.email = auth['info']['email']
      u.name = auth['info']['name']
    end
    session[:user_id] = user.id
    redirect_to root_path, notice: "Logged in!"
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Logged out!"
  end

  def failure
    flash[:error] = "Authentication failed, please try again."
    redirect_to root_path
  end
end
