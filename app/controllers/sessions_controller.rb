class SessionsController < ApplicationController
  skip_before_action :check_editing_mode, only: %i[create destroy failure]
  # Login is project-agnostic and must work on the apex (no subdomain), so skip
  # the project resolution + db wiring that the rest of the app requires.
  skip_before_action :resolve_project, :set_db
  layout false, only: %i[login password_login]

  # Email/password sign-in.
  def password_login
    user = User.authenticate_email(params[:email], params[:password])
    if user
      user.apply_pending_invitations!
      session[:user_id] = user.id
      redirect_to root_path, notice: "Welcome back#{user.name.present? ? ", #{user.name}" : ''}!"
    else
      @email = params[:email]
      flash.now[:error] = 'Wrong email or password.'
      render :login, status: :unprocessable_entity
    end
  end

  def create
    if user_signed_in?
      redirect_to root_path, notice: 'Already logged in!'
      return
    end

    auth = request.env['omniauth.auth']
    user = User.from_omniauth(auth) # saves automatically
    user.apply_pending_invitations! # grant any roles this email was invited to
    session[:user_id] = user.id
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
