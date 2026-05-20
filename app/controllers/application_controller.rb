class ApplicationController < ActionController::Base
  before_action :set_db, :set_descriptions, :set_edit_mode
  before_action :check_editing_mode, only: [:new, :edit, :create, :update, :destroy]
  before_action :check_session_timeout
  before_action :update_session_timestamp

  http_basic_authenticate_with name: "#{ENV['EDIT_USER']}", password: "#{ENV['EDIT_PASSWORD']}" if Rails.env.production?

  helper_method :current_user, :user_signed_in?, :require_authentication, :user_role?, :require_role, :require_superuser, :require_dig_director, :require_area_supervisor, :require_square_supervisor, :require_lab_supervisor, :current_dig

  private
  def set_db
    @db = CouchDB.main_db
    @auth_db = CouchDB.auth_db
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

  def update_session_timestamp
    session[:last_seen] = Time.current
  end

  # 30-minute sliding expiration
  def check_session_timeout
    timeout_minutes = 30.minutes

    if session[:last_seen].present? && (Time.current - Time.zone.parse(session[:last_seen].to_s)) > timeout_minutes
      reset_session
      flash[:alert] = "Your session has expired due to inactivity."
    end
  end

  def user_signed_in?
    !!current_user
  end

  def current_user
    return nil unless session[:user_id]

    # Cache current user so we aren't looking them up multiple times per request
    if session[:user_id]
      @current_user ||= User.find(session[:user_id])
    else
      @current_user = nil
    end
  end

  def require_authentication
    return if user_signed_in?

    flash[:error] = "You must be logged in to access this section"
    redirect_to root_path
    false
  end

  def user_role?(role, scope: nil)
    role = role.to_s
    scope = scope.is_a?(Array) ? scope.map(&:to_s) : scope.to_s if scope
    Rails.logger.debug "Checking if user has role #{role} with scope #{scope}"
    return true if role.to_s == 'viewer'
    return false unless user_signed_in?
    return false unless current_user.role_at_least? role
    return current_user.role_scopes.include?(scope) if scope && current_user.role == role

    true
  end

  def require_role(role, scope: nil)
    require_authentication
    return if performed? # Don't check role if authentication check failed

    role = role.to_s
    unless current_user.role_at_least? role
      flash[:error] = "You must be a(n) #{role.humanize.downcase} to access this section"
      redirect_to root_path
      return false
    end

    if scope && current_user.role == role && !current_user.role_scopes.include?(scope)
      flash[:error] = "You do not have access to this section"
      redirect_to root_path
      return false
    end

    true
  end

  def require_superuser = require_role :superuser

  def require_dig_director = require_role :dig_director, scope: current_dig

  def require_area_supervisor(area_id) = require_role :area_supervisor, scope: area_id

  def require_square_supervisor(square_id) = require_role :square_supervisor, scope: square_id

  def require_lab_supervisor = require_role :lab_supervisor

  # Not sure how handling multiple digs will work ATP.
  # This is good enough to get per-dig permissions going.
  # Needs refactoring later.
  def current_dig
    'opendig'
  end
end
