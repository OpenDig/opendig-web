class RegistrarController < ApplicationController
  before_action :set_item, only: [:show, :edit, :update]

  def index
    @seasons = @db.view('opendig/seasons', {group: true})["rows"].map{|row| row["key"]}.sort.reverse
    @selected_season = params[:season] || @seasons.first
    @finds = Registrar.all_by_season(@selected_season.to_i)
  end

  def show

  end

  def edit

  end

  def update
    pails = @doc['pails']
    pail = pails.select{|p| p['pail_number'].to_s == @pail_id.to_s}.first
    item = pail['finds'].select{|item| item.dig('field_number') == @item_number}.first
    item.merge!(params[:locus][:find].to_enum.to_h)


    if @doc.save
      flash[:success] = "Success! Find Updated"
      redirect_to registrar_path(id: @item_id, pail_id: @pail_id, item_number: @item_number, item_locus_code: @item_locus_code)
    else
      flash.now[:error] = "Something went wrong"
      render :edit
    end
  end

  def set_item
    @item_id = params[:id]
    @item_number = params[:item_number]
    @item_locus_code = params[:item_locus_code]
    @area, @square, @locus_code = @item_locus_code.split('.')
    @pail_id = params[:pail_id]
    @doc = @db.get(@item_id)
    @find = @doc['pails'].select{|pail| pail['pail_number'].to_s == @pail_id.to_s}.first.dig('finds').select{|item| item.dig('field_number') == @item_number}.first
  end

end