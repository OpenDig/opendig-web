class SquaresController < ApplicationController
  before_action :set_area_and_squares

  def index
  end

  def new
  end

  def create
    new_square = params[:square].upcase
    if @squares.include? new_square
      flash.now[:error] = "Square #{new_square} in area #{@area} already exists!"
      render :new
    else
      doc = { 'temp-doc' => true }.merge({ 'square' => new_square, 'area' => @area })
      if @db.save_doc(doc)
        flash[:success] = "Square #{new_square} in area #{@area} created!"
        redirect_to area_squares_path(@area)
      else
        flash.now[:error] = 'Something went wrong'
        render :new
      end
    end
  end

  private

  def set_area_and_squares
    @area = params[:area_id]
    @squares = @db.view('opendig/squares',
                        { group: true, start_key: [@area], end_key: [@area, {}] })['rows'].map do |row|
      row['key'][1]
    end
  end
end
