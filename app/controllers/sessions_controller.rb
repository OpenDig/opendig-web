class SessionsController < ApplicationController
  skip_before_action :check_editing_mode, only: %i[create destroy failure]

  def create
    if user_signed_in?
      puts "User signed in already: #{current_user.id}"
      redirect_to root_path, notice: 'Already logged in!'
      return
    end

    puts "User not signed in"
    auth = request.env['omniauth.auth']
    user = User.from_omniauth(auth) # saves automatically
    session[:user_id] = user.id
    puts "User now signed in: #{current_user.id}"
    greeting = user.name.blank? ? '!' : ". Welcome #{user.name}!"
    redirect_to root_path, notice: "Logged in with #{user.email}" + greeting
  end

  def destroy
    reset_session
    redirect_to root_path, notice: 'Logged out!'
  end

  def failure
    flash[:error] = 'Authentication failed, please try again.'
    redirect_to root_path
  end
end
