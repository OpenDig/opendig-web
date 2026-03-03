class SquaresController < ApplicationController
  before_action :require_editor, except: [:index]
  before_action :set_area_and_squares

  def index
  end

  def new
  end

  def create
    new_square = params[:square].upcase
    unless @squares.include? new_square
      doc = {"temp-doc" => true}.merge({"square" => new_square, "area" => @area})
      if @db.save_doc(doc)
        flash[:success] = "Square #{new_square} in area #{@area} created!"
        redirect_to area_squares_path(@area)
      else
        flash.now[:error] = "Something went wrong"
        render :new
      end
    else
      flash.now[:error] = "Square #{new_square} in area #{@area} already exists!"
      render :new
    end
  end

  private
    def set_area_and_squares
      @area = params[:area_id]
      @squares = @db.view('opendig/squares', {group: true, start_key: [@area], end_key: [@area, {}]})["rows"].map{|row| row["key"][1]}
    end

end