# AreasController manages areas, which are the top-level organizational unit in OpenDig.
# It allows users to view and create areas.
class AreasController < ApplicationController
  before_action :load_areas, only: :create
  before_action :new_area_must_be_unique, only: :create

  def index
    @areas = @db.view('opendig/areas', { group: true })['rows']
  end

  def new; end

  def create
    new_area = params[:area].upcase
    doc = { area: new_area, 'temp-doc': true }
    if @db.save_doc(doc)
      flash[:success] = "area #{new_area} created!"
      redirect_to areas_path
    else
      flash.now[:error] = 'Something went wrong'
      render :new
    end
  end

  private

  def load_areas
    @areas = @db.view('opendig/areas', { group: true })['rows'].map { |area| area['key'] } # rubocop:disable Rails/Pluck
  end

  def new_area_must_be_unique
    return unless @areas.include? params[:area].upcase

    flash.now[:error] = "area #{params[:area]} already exists!"
    render :new
  end
end
