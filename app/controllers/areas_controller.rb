class AreasController < ApplicationController
  before_action :require_editor, only: [:new, :create]

  def index
    @areas = @db.view('opendig/areas', {group: true})['rows']
  end

  def new
  end

  def create
    @areas = @db.view('opendig/areas', {group: true})['rows'].map{|area| area["key"]}
    new_area = params[:area].upcase
    unless @areas.include? new_area
      doc = {"area": new_area, "temp-doc": true}
      if @db.save_doc(doc)
        flash[:success] = "area #{new_area} created!"
        redirect_to areas_path
      else
        flash.now[:error] = "Something went wrong"
        render :new
      end
    else
      flash.now[:error] = "area #{new_area} already exists!"
      render :new
    end
  end
end