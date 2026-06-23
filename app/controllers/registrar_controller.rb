class RegistrarController < ApplicationController
  # Supervisors may read the registrar; only registrar/dig_director/superuser may write.
  before_action :require_registrar_read
  before_action :require_registrar_write, only: %i[new create edit update destroy]
  before_action :set_item, only: [:show, :edit, :update]

  def index
    # Seasons present in the data, plus the current one so a new season is
    # selectable before any finds exist for it. Default to the current season.
    current_season = Date.current.year
    data_seasons = @db.view('opendig/seasons', { group: true })['rows'].map { |row| row['key'].to_i }
    @seasons = (data_seasons + [current_season]).uniq.sort.reverse
    @selected_season = (params[:season].presence || current_season).to_i

    @stages = Registrar::STAGES
    all_finds = Registrar.all_by_season(@selected_season)

    @stage_counts = Hash.new(0)
    all_finds.each { |find| @stage_counts[find.stage] += 1 }
    @stage_counts['all'] = all_finds.size

    @selected_stage = params[:status].presence || @stages.first[:key]
    @finds = @selected_stage == 'all' ? all_finds : all_finds.select { |find| find.stage == @selected_stage }
    @finds.sort_by! { |find| [find.formatted_locus_code, find.pail_number] }
  end

  def show; end

  def edit; end

  def update
    pail = embedded_rows(@doc['pails']).find { |p| p['pail_number'].to_s == @pail_id.to_s }
    item = pail && embedded_rows(pail['finds']).find { |i| i['field_number'].to_s == @item_number }

    return redirect_to(registrar_index_path, alert: 'That find could no longer be located.') if item.nil?

    item.merge!(params[:locus][:find].to_enum.to_h)

    if @doc.save
      flash[:success] = 'Success! Find Updated'
      redirect_to registrar_path(id: @item_id, pail_id: pail['pail_number'], item_number: item['field_number'],
                                 item_locus_code: @item_locus_code)
    else
      flash.now[:error] = 'Something went wrong'
      render :edit
    end
  end

  def set_item
    @item_id = params[:id]
    @item_number = params[:item_number].to_s
    @item_locus_code = params[:item_locus_code]
    @area, @square, @locus_code = @item_locus_code.to_s.split('.')
    @pail_id = params[:pail_id]
    @doc = @db.get(@item_id)

    pail = embedded_rows(@doc['pails']).find { |p| p['pail_number'].to_s == @pail_id.to_s }
    # Compare as strings: field_number may be stored as a number while the URL
    # param is a string, which otherwise silently misses and leaves @find nil.
    @find = pail && embedded_rows(pail['finds']).find { |item| item['field_number'].to_s == @item_number }

    return if @find

    redirect_to registrar_index_path, alert: 'That find could not be located.'
  end

  # Coerce an embedded collection (pails, finds) into an array of hashes. Some
  # legacy docs store these as a Hash keyed by id rather than an array; iterating
  # that yields [key, value] pairs and breaks item['field'] lookups. Returns the
  # same hash objects (not copies) so in-place mutation + @doc.save still works.
  def embedded_rows(collection)
    rows = collection.is_a?(Hash) ? collection.values : collection
    Array(rows).select { |row| row.is_a?(Hash) }
  end
end
