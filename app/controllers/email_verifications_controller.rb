class EmailVerificationsController < ApplicationController
  # Confirmation links are project-agnostic and point at the apex.
  skip_before_action :resolve_project, :set_db

  def show
    user = User.find_by_token(params[:token], purpose: :email_verification)
    unless user
      flash[:error] = 'That confirmation link is invalid or has expired. Sign in to get a new one.'
      return redirect_to login_path
    end

    user.verify_email! if user.pending_verification?
    user.apply_pending_invitations!
    session[:user_id] = user.id
    redirect_to root_path, notice: "Thanks for confirming your email, #{user.name}!"
  end
end
