class SessionsController < ApplicationController
  def create
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
end
