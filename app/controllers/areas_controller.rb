class AreasController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:favorite, :unfavorite]
  before_action :load_favorites

  def index
    @areas = @db.view('opendig/areas', {group: true})['rows']
  end

  def toggle_favorite
    @area_key = params[:area_key].to_s
    return render json: { error: 'area_key is required' }, status: :unprocessable_entity if @area_key.blank?

    
    @favorited = @favorites.include?(@area_key)
    Rails.logger.info "  Attempting to toggle favorite: #{@area_key.inspect}, is#{@favorited ? '' : ' not'} favorited"
    if @favorited
      @favorites.delete(@area_key)
      Rails.logger.info "    Unfavoriting #{@area_key}..."
    else
      Rails.logger.info "    Favoriting #{@area_key}..."
      @favorites << @area_key
    end
    store_favorites(@favorites)
    @favorited = !@favorited
    Rails.logger.info "    Favorite toggled"
    
    respond_to do |format|
      format.turbo_stream
    end
  end

  def new; end

  def create
    @areas = @db.view('opendig/areas', { group: true })['rows'].map { |area| area['key'] }
    new_area = params[:area].upcase
    if @areas.include? new_area
      flash.now[:error] = "area #{new_area} already exists!"
      render :new
    else
      doc = { "area": new_area, "temp-doc": true }
      if @db.save_doc(doc)
        flash[:success] = "area #{new_area} created!"
        redirect_to areas_path
      else
        flash.now[:error] = 'Something went wrong'
        render :new
      end
    end
  end

  private

  def load_favorites
    @favorites = JSON.parse(cookies.permanent[:favorites] || "[]")
  end

  def store_favorites(favorites)
    cookies.delete(:favorites)
    cookies.permanent[:favorites] ||= favorites.to_json
  end
end
