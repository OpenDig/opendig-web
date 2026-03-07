class ApplicationController < ActionController::Base # rubocop:disable Style/Documentation
  before_action :set_db, :set_descriptions, :set_edit_mode
  before_action :check_editing_mode, only: [:new, :edit, :create, :update, :destroy] # rubocop:disable Rails/LexicallyScopedActionFilter

  if Rails.env.production?
    http_basic_authenticate_with(
      name: ENV.fetch('EDIT_USER', nil).to_s,
      password: ENV.fetch('EDIT_PASSWORD', nil).to_s
    )
  end

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
    return if @editing_enabled

    flash[:error] = 'Editing is disabled'
    redirect_to request.referer
  end
end
