class ApplicationController < ActionController::Base
  before_action :set_db, :set_descriptions, :set_edit_mode
  before_action :check_editing_mode, only: %i[new edit create update destroy]

  if Rails.env.production?
    http_basic_authenticate_with name: (ENV['EDIT_USER']).to_s, password: (ENV['EDIT_PASSWORD']).to_s
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

  def toggle_favorite(category, resource_id)
    load_favorites

    @favorited = favorited?(category => resource_id)
    if @favorited
      remove_favorite category => resource_id
    else
      add_favorite category => resource_id
    end
    @favorited = !@favorited # Toggle before responding to ensure the view reflects the new state
  end

  def favorite_params
    params.require(:favorite).permit(:category, :resource_id)
  end

  def load_favorites
    @favorites = JSON.parse(cookies.permanent[:favorites] || "{}")
  end

  def save_favorites(favorites = @favorites || {})
    cookies.permanent[:favorites] = favorites.to_json
    load_favorites
  end

  def add_favorite(**categories)
    Rails.logger.info "  Adding favorite: #{categories.inspect}"

    categories.each do |category, resource_id|
      @favorites[category.to_s] ||= []
      @favorites[category.to_s] << resource_id unless @favorites[category.to_s].include?(resource_id)
    end

    save_favorites
  end

  def remove_favorite(**categories)
    Rails.logger.info "  Removing favorite: #{categories.inspect}"

    categories.each do |category, resource_id|
      @favorites[category.to_s] ||= []
      @favorites[category.to_s].delete(resource_id)
    end

    save_favorites
  end

  def favorited?(**categories)
    categories.all? do |category, resource_id|
      @favorites[category.to_s]&.include?(resource_id.to_s)
    end
  end
end
