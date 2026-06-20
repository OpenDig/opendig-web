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
      redirect_to post_login_destination, allow_other_host: true, notice: 'Already logged in!'
      return
    end

    auth = request.env['omniauth.auth']
    user = User.from_omniauth(auth) # saves automatically
    user.apply_pending_invitations! # grant any roles this email was invited to
    session[:user_id] = user.id
    greeting = user.name.blank? ? '!' : ". Welcome #{user.name}!"
    # The handshake ran on the apex; send the user back to the subdomain they
    # started on (the shared session cookie keeps them signed in there).
    redirect_to post_login_destination, allow_other_host: true, notice: "Logged in with #{user.email}#{greeting}"
  end

  def destroy
    reset_session
    redirect_to root_path, notice: 'Logged out!'
  end

  def failure
    flash[:error] = 'Authentication failed, please try again.'
    redirect_to root_path
  end

  private

  # After an apex OAuth callback, return to the subdomain the user came from
  # (OmniAuth stores the request's `origin` param as omniauth.origin). Only honor
  # an origin on our own registrable domain -- never an arbitrary host -- to avoid
  # an open redirect; otherwise fall back to the local root.
  def post_login_destination
    origin = request.env['omniauth.origin']
    return root_path if origin.blank?

    uri = begin
      URI.parse(origin)
    rescue URI::InvalidURIError
      nil
    end
    return root_path unless uri&.host

    registrable = request.domain
    same_site = uri.host == registrable || uri.host.end_with?(".#{registrable}")
    same_site ? origin : root_path
  end
end
