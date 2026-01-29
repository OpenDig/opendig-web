class AreasController < ApplicationController
  def index
    @areas = @db.view('opendig/areas', { group: true })['rows']
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
