# RegistrarController manages the registration of finds to the database.
# It allows users to view and edit find records based on their
# season and registration status.
class RegistrarController < ApplicationController
  before_action :set_item, only: [:show, :edit, :update]

  def index
    load_seasons
    @status = status_descriptions[params[:status]&.to_sym] || status_descriptions[:unregistered]
    @selected_season = params[:season] || @seasons.first
    locate_finds
  end

  def show; end

  def edit; end

  def update
    item = update_find

    if @doc.save
      flash[:success] = 'Success! Find Updated'
      redirect_to registrar_path(id: @item_id, pail_id: @pail['pail_number'], item_number: item['field_number'],
                                 item_locus_code: @item_locus_code)
    else
      flash.now[:error] = 'Something went wrong'
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
    locate_find
  end

  private

  def load_seasons
    @seasons = @db.view('opendig/seasons', { group: true })['rows'].map { |row| row['key'] }.sort.reverse # rubocop:disable Rails/Pluck
  end

  def locate_finds
    @finds = Registrar.all_by_season(@selected_season.to_i)
                      .select { |reg| reg.state == @status || @status == 'all' }
                      .sort_by { |find| [find.formatted_locus_code, find.pail_number] }
  end

  def locate_find
    @find = @doc['pails']
            .find { |pail| pail['pail_number'].to_s == @pail_id.to_s }['finds']
            .find { |item| item['field_number'] == @item_number }
  end

  def update_find
    pails = @doc['pails']
    @pail = pails.find { |p| p['pail_number'].to_s == @pail_id.to_s }
    item = @pail['finds'].find { |find| find['field_number'] == @item_number }
    item.merge!(params[:locus][:find].to_enum.to_h)
    item
  end

  def status_descriptions
    {
      all: 'all',
      unregistered: 'unregistered',
      initial: 'initial registration',
      wip: 'WIP',
      completed: 'registrarion complete'
    }
  end
end
