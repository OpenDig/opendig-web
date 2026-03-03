class RegistrarController < ApplicationController
  before_action :require_editor
  before_action :set_item, only: [:show, :edit, :update]

  def index
    @seasons = @db.view('opendig/seasons', {group: true})["rows"].map{|row| row["key"]}.sort.reverse

    status = {
      all: 'all',
      unregistered: 'unregistered',
      initial: 'initial registration',
      wip: 'WIP',
      completed: 'registrarion complete'
    }


    @status = status[params[:status]&.to_sym] || status[:unregistered]

    @selected_season = params[:season] || @seasons.first
    if @status == 'all'
      @finds = Registrar.all_by_season(@selected_season.to_i)
    else
      @finds = Registrar.all_by_season(@selected_season.to_i).select{|reg| reg.state == @status}
    end
    @finds.sort_by!{|find| [find.formatted_locus_code, find.pail_number]}
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
      redirect_to registrar_path(id: @item_id, pail_id: pail['pail_number'], item_number: item['field_number'], item_locus_code: @item_locus_code)
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