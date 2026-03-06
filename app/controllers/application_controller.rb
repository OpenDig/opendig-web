class ApplicationController < ActionController::Base
  before_action :set_db, :set_descriptions, :set_edit_mode
  before_action :check_editing_mode, only: [:new, :edit, :create, :update, :destroy]
  before_action :check_session_timeout
  before_action :update_session_timestamp

  http_basic_authenticate_with name: "#{ENV['EDIT_USER']}", password: "#{ENV['EDIT_PASSWORD']}" if Rails.env.production?

  helper_method :current_user, :user_signed_in?, :require_authentication, :require_role

  private
  def set_db
    @db = Rails.application.config.couchdb
  end

  def set_descriptions
    @descriptions = Rails.application.config.descriptions
  end

  def set_edit_mode
    @editing_enabled = ENV['EDITING_ENABLED'] || false
  end

  def check_editing_mode
    unless @editing_enabled
      flash[:error] = "Editing is disabled"
      redirect_to request.referer
    end
  end

  # 30-minute sliding expiration
  def update_session_timestamp
    session[:last_seen] = Time.current
  end

  def check_session_timeout
    timeout_minutes = 30.minutes
    
    if session[:last_seen].present? && (Time.current - Time.parse(session[:last_seen].to_s)) > timeout_minutes
      reset_session
      flash[:alert] = "Your session has expired due to inactivity."
    end
  end

  def user_signed_in?
    !!current_user
  end

  def current_user
    return nil unless session[:user_id]
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def require_authentication
    return if user_signed_in?

    flash[:error] = "You must be logged in to access this section"
    redirect_to root_path
    return
  end

  def require_role(role)
    require_authentication
    return if performed? # Don't check role if authentication check failed

    unless current_user.role_at_least? role
      flash[:error] = "You must be a(n) #{role} to access this section"
      redirect_to root_path
      return
    end
  end

  User.roles.keys.each do |role|
    define_method("require_#{role}") do
      require_role(role)
    end

    helper_method "require_#{role}"
  end
end
