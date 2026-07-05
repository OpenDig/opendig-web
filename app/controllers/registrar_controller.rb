class RegistrarController < ApplicationController
  # Supervisors may read the registrar; only registrar/dig_director/superuser may write.
  before_action :require_registrar_read
  before_action :require_registrar_write, only: %i[new create edit update destroy discard restore set_cover]
  before_action :set_item, only: %i[show edit update discard restore set_cover]

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
    submitted = params[:locus][:find].to_enum.to_h
    ok = save_find_change do |find|
      find.merge!(submitted)
      # Multi-value fields (Colour, Decoration) submit an array with a trailing
      # blank placeholder; drop blanks so stored data stays clean.
      find.transform_values! { |v| v.is_a?(Array) ? v.compact_blank : v }
    end

    if ok
      flash[:success] = 'Success! Find Updated'
      redirect_to registrar_path(id: @item_id, pail_id: @pail['pail_number'],
                                 item_number: @find['field_number'], item_locus_code: @item_locus_code)
    else
      flash.now[:error] = 'This find could not be saved (it may have just been changed elsewhere). ' \
                          'Please review and try again.'
      render :edit
    end
  end

  # Discard a find the registrar decided is not a find: it's returned to the
  # field with a recorded reason. The find stays on the board in the Discarded
  # stage rather than being deleted, so the decision is auditable.
  def discard
    reason = params[:discard_reason].to_s.strip
    if reason.blank?
      redirect_to registrar_path(**find_path_params),
                  alert: 'Please provide a reason for discarding this find.'
      return
    end

    ok = save_find_change do |find|
      find.merge!(
        'state' => Registrar::DISCARDED_STATE,
        'discard_reason' => reason,
        'discarded_at' => Time.current.iso8601,
        'discarded_by' => current_user&.email
      )
    end

    if ok
      redirect_to registrar_index_path(season: params[:season]),
                  notice: "Find ##{@find['field_number']} discarded and returned to the field."
    else
      redirect_to registrar_path(**find_path_params), alert: 'Something went wrong discarding the find.'
    end
  end

  # Undo a discard: the find returns to Incoming and the discard metadata is
  # cleared, so a mistaken discard isn't a dead end.
  def restore
    ok = save_find_change do |find|
      find.merge!('state' => Registrar::RESTORED_STATE)
      find.delete('discard_reason')
      find.delete('discarded_at')
      find.delete('discarded_by')
    end

    if ok
      redirect_to registrar_path(**find_path_params), notice: 'Find restored to Incoming.'
    else
      redirect_to registrar_path(**find_path_params), alert: 'Something went wrong restoring the find.'
    end
  end

  # Choose which of a find's photos is the cover (main) image. The cover_key
  # must be one of the find's actual photos, so a bad value can't be stored.
  def set_cover
    key = params[:cover_key].to_s
    return redirect_to registrar_path(**find_path_params), alert: 'That photo could not be found.' unless helpers.find_photos(@find).any? { |p| p['key'] == key }

    ok = save_find_change { |find| find['cover_key'] = key }
    if ok
      redirect_to registrar_path(**find_path_params), notice: 'Cover photo updated.'
    else
      redirect_to registrar_path(**find_path_params), alert: 'Could not update the cover photo.'
    end
  end

  def set_item
    @item_id = params[:id]
    @item_number = params[:item_number].to_s
    @item_locus_code = params[:item_locus_code]
    @area, @square, @locus_code = @item_locus_code.to_s.split('.')
    @pail_id = params[:pail_id]
    @doc = @db.get(@item_id)
    locate_find

    return if @find

    redirect_to registrar_index_path, alert: 'That find could not be located.'
  end

  # Locate the pail + find inside the current @doc. Compare as strings:
  # field_number may be stored as a number while the URL param is a string.
  def locate_find
    @pail = embedded_rows(@doc['pails']).find { |p| p['pail_number'].to_s == @pail_id.to_s }
    @find = @pail && embedded_rows(@pail['finds']).find { |i| i['field_number'].to_s == @item_number }
  end

  # Apply a change to the find and save, retrying on a 409 conflict. CouchRest
  # RAISES CouchRest::Conflict on 409 (it never returns false), so a concurrent
  # edit to the same locus doc used to 500 and lose the registrar's change. On
  # conflict we re-fetch the doc, re-locate the find, and RE-APPLY the block onto
  # the latest data (so the change lands on top of the concurrent edit instead of
  # clobbering it). Returns true on success, false if it can't be located or
  # still conflicts after several tries. The block receives the (fresh) find.
  def save_find_change(attempts: 3)
    attempts.times do |i|
      if i.positive?
        @doc = @db.get(@item_id)
        locate_find
      end
      return false unless @find

      yield @find
      begin
        @doc.save
        return true
      rescue CouchRest::Conflict
        next
      end
    end
    false
  end

  # The composite params that identify a find across registrar routes.
  def find_path_params
    { id: @item_id, pail_id: @pail_id, item_number: @item_number, item_locus_code: @item_locus_code }
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
