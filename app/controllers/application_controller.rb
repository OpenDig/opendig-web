class ApplicationController < ActionController::Base
  before_action :set_db, :set_descriptions, :set_edit_mode
  before_action :check_editing_mode, only: [:new, :edit, :create, :update, :destroy]

  http_basic_authenticate_with name: "#{ENV['EDIT_USER']}", password: "#{ENV['EDIT_PASSWORD']}" if Rails.env.production?

  helper_method :current_user, :user_signed_in?, :require_authentication, :require_admin

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

  def user_signed_in?
    !!current_user
  end

  def current_user
    @current_user ||= User.find(session[:user_id]) if session[:user_id]
  end

  def require_authentication
    unless user_signed_in?
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end

  def require_admin
    unless user_signed_in? && current_user.admin?
      flash[:error] = "You must be an admin to access this section"
      redirect_to root_path
    end
  end
end
