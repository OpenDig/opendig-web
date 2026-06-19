class RegistrationsController < ApplicationController
  # Signup is project-agnostic and must work on the apex (no subdomain).
  skip_before_action :resolve_project, :set_db
  layout false

  def new; end

  def create
    @user = User.register(
      email: params[:email],
      password: params[:password],
      password_confirmation: params[:password_confirmation],
      name: params[:name]
    )

    if @user.save
      @user.apply_pending_invitations! # grant any roles this email was invited to
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Welcome to OpenDig, #{@user.name}!"
    else
      @name = params[:name]
      @email = params[:email]
      flash.now[:error] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end
end
