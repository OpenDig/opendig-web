class RegistrationsController < ApplicationController
  # Signup is project-agnostic and must work on the apex (no subdomain).
  skip_before_action :resolve_project, :set_db
  layout 'auth'

  # A person takes longer than this to fill in the form; bots usually don't.
  MINIMUM_FILL_TIME = 3.seconds

  def new
    @email = params[:email]
    @form_token = form_token
  end

  def create
    @name = params[:name]
    @email = params[:email].to_s.strip.downcase

    # Answer bots as if signup worked, so they learn nothing, but create nothing.
    return render :check_email if honeypot_filled? || submitted_too_fast?
    return rerender_form('Something went wrong, please try again.') unless form_started_at

    mail_enabled? ? create_with_confirmation : create_and_sign_in
  end

  private

  def create_with_confirmation
    # Don't reveal whether an address already has an account. An unconfirmed
    # account gets a fresh confirmation link; a confirmed one gets nothing.
    if (existing = User.for_email(@email))
      UserMailer.email_verification(existing.id_as_string).deliver_later if existing.pending_verification?
      return render :check_email
    end

    @user = build_user(verify_email: true)
    if @user.save
      UserMailer.email_verification(@user.id_as_string).deliver_later
      render :check_email
    else
      rerender_form(@user.errors.full_messages.to_sentence)
    end
  end

  # Without email there's no way to confirm the address, so sign straight in.
  def create_and_sign_in
    return rerender_form('An account with this email already exists. Try signing in.') if User.for_email(@email)

    @user = build_user(verify_email: false)
    if @user.save
      @user.apply_pending_invitations! # grant any roles this email was invited to
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Welcome to OpenDig, #{@user.name}!"
    else
      rerender_form(@user.errors.full_messages.to_sentence)
    end
  end

  def build_user(verify_email:)
    User.register(
      email: @email,
      password: params[:password],
      password_confirmation: params[:password_confirmation],
      name: @name,
      verify_email: verify_email
    )
  end

  def rerender_form(message)
    @form_token = form_token
    flash.now[:error] = message
    render :new, status: :unprocessable_entity
  end

  def form_verifier = Rails.application.message_verifier(:signup_form)

  # Signed timestamp of when the form was rendered.
  def form_token = form_verifier.generate(Time.current.to_i, expires_in: 1.day)

  def form_started_at
    started = form_verifier.verified(params[:form_token].to_s)
    started && Time.zone.at(started)
  end

  def honeypot_filled? = params[:website].present?

  def submitted_too_fast?
    started = form_started_at
    started.present? && Time.current - started < MINIMUM_FILL_TIME
  end
end
