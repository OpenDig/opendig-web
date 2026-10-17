class PasswordResetsController < ApplicationController
  # Password resets are project-agnostic and must work on the apex, and don't
  # depend on whether dig data editing is enabled.
  skip_before_action :resolve_project, :set_db, :check_editing_mode
  before_action :require_mail
  layout 'auth'

  def new; end

  def edit
    @user = user_from_token
  end

  # Always give the same answer, so this can't be used to find out which
  # addresses have accounts.
  def create
    email = params[:email].to_s.strip.downcase
    user = User.for_email(email)
    UserMailer.password_reset(user.id_as_string).deliver_later if user
    redirect_to login_path, notice: "If #{email} has an OpenDig account, we've sent it a link to reset the password."
  end

  def update
    @user = user_from_token
    return unless @user

    if params[:password].blank?
      flash.now[:error] = "Password can't be blank"
      return render :edit, status: :unprocessable_entity
    end

    @user.password = params[:password]
    @user.password_confirmation = params[:password_confirmation]
    @user.pending_verification = nil # following the emailed link proves they own the address

    if @user.save
      @user.apply_pending_invitations!
      session[:user_id] = @user.id
      redirect_to root_path, notice: 'Your password has been changed.'
    else
      flash.now[:error] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def require_mail
    return if mail_enabled?

    flash[:error] = "Password reset by email isn't available yet. Please ask a dig director for help."
    redirect_to login_path
  end

  def user_from_token
    user = User.find_by_token(params[:token], purpose: :password_reset)
    return user if user

    flash[:error] = 'That reset link is invalid or has expired. Please request a new one.'
    redirect_to new_password_reset_path
    nil
  end
end
