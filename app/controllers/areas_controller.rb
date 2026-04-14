class AreasController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:favorite, :unfavorite]

  def index
    @areas = @db.view('opendig/areas', {group: true})['rows']
    favorite_keys = session[:favorite_area_keys] || []
    @favorite_areas = @areas.select { |area| favorite_keys.include?(area['key']) }
  end

  def favorite
    area_key = params[:area_key].to_s
    Rails.logger.info "FAVORITE ACTION - area_key: #{area_key}, all params: #{params.inspect}"
    return render json: { error: 'area_key is required' }, status: :unprocessable_entity if area_key.blank?

    favorite_area_keys = session[:favorite_area_keys] || []
    unless favorite_area_keys.include?(area_key)
      favorite_area_keys << area_key
      session[:favorite_area_keys] = favorite_area_keys
    end
    
    Rails.logger.info "FAVORITED #{area_key}, session now: #{session[:favorite_area_keys].inspect}"
    
    is_favorited = favorite_area_keys.include?(area_key)
    respond_to do |format|
      format.turbo_stream { render :favorite, locals: { area_key: area_key, is_favorited: true } }
      format.html { render partial: 'areas/favorite_toggle', locals: { area_key: area_key} }
    end
  end

  def unfavorite
    area_key = params[:area_key].to_s
    Rails.logger.info "UNFAVORITE ACTION - area_key: #{area_key}, all params: #{params.inspect}"
    return render json: { error: 'area_key is required' }, status: :unprocessable_entity if area_key.blank?

    favorite_area_keys = session[:favorite_area_keys] || []
    favorite_area_keys.delete(area_key)
    session[:favorite_area_keys] = favorite_area_keys

    Rails.logger.info "UNFAVORITED #{area_key}, session now: #{session[:favorite_area_keys].inspect}"
    render json: { favorited: false, area_key: area_key }
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
end
