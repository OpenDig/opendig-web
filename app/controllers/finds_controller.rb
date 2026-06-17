class FindsController < ApplicationController
  def index
    @area = params[:area_id]
    @square = params[:square_id]
    @finds = @db.view('opendig/finds_for_square',
                      { reduce: false, start_key: ["#{@area}.#{@square}"],
                        end_key: ["#{@area}.#{@square}", {}] })['rows'].map do |row|
      Find.new(row['value'])
    end
    @finds.sort_by! { |find| [-find.season.to_i, find.field_number.to_i] }
  end
end
