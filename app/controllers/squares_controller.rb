# SquaresController manages the squares in an area. It allows users to view the squares in an area,
# create new squares, and handles the logic for ensuring that duplicate squares are not created
# within the same area.
class SquaresController < ApplicationController
  before_action :set_area_and_squares
  before_action :new_square_must_be_unique, only: :create

  def index; end

  def new; end

  def create
    new_square = params[:square].upcase
    if save_doc(new_square)
      flash[:success] = "Square #{new_square} in area #{@area} created!"
      redirect_to area_squares_path(@area)
    else
      flash.now[:error] = 'Something went wrong'
      render :new
    end
  end

  private

  def save_doc(new_square)
    doc = { 'temp-doc' => true }.merge({ 'square' => new_square, 'area' => @area })
    @db.save_doc(doc)
  end

  def set_area_and_squares
    @area = params[:area_id]
    @squares = @db.view('opendig/squares',
                        { group: true, start_key: [@area], end_key: [@area, {}] })['rows'].map do |row|
      row['key'][1]
    end
  end

  def new_square_must_be_unique
    square = params[:square].upcase
    return unless @squares.include? square

    flash.now[:error] = "Square #{square} in area #{@area} already exists!"
    render :new
  end
end
