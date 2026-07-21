class LociController < ApplicationController
  before_action -> { require_square_supervisor([params[:area_id], params[:square_id]]) },
                except: [:index, :show]
  before_action :set_locus, only: [:show, :edit, :update]
  def index
    @area = params[:area_id]
    @square = params[:square_id]
    @loci = @db.view('opendig/loci',
                     { group: true, start_key: [@area, @square], end_key: [@area, @square, {}] })['rows'].map do |row|
      Locus.new(row['key'])
    end
    # Convention-named photos in this square not yet linked to a locus.
    @pending_photos = BulkPhoto.pending_for_square(@area, @square)
  end

  def search
    query = params[:q].to_s.strip
    @search_query = query
    @search_results = query.present? ? loci_for_search(query) : []

    respond_to do |format|
      format.html
      format.json { render json: @search_results }
    end
  end

  def show
  end

  def edit; end

  def new
    @area = params[:area_id]
    @square = params[:square_id]
    @locus = { 'locus_type' => params[:type] }
  end

  def update
    repaired = repair_nested_params(params[:locus].to_enum.to_h)
    normalize_deletable_arrays!(repaired)
    merged = save_locus_with_retry(repaired)

    if merged
      flash[:success] = 'Success! Locus Updated'
      redirect_to area_square_locus_path(@area, @square, merged['code'])
    else
      flash.now[:error] = 'Someone else changed this locus while you were editing, ' \
                          'so it was not saved. Please review the latest data and save again.'
      render :edit
    end
  end

  def create
    new_locus = params[:locus]
    if @db.save_doc(new_locus)
      flash[:success] = 'Success! New Locus Created'
      redirect_to area_square_loci_path(params[:area_id], params[:square_id])
    else
      flash.now[:error] = 'Something went wrong'
      render :new
    end
  end

  private

    # Sections rendered as removable rows (stratigraphies, supplements) submit no
    # key at all once the user deletes every row, so LocusMerge would keep the
    # stored array and the deletion of the LAST row silently wouldn't persist.
    # Each such form emits a hidden `<section>_present` marker; when it's set but
    # the array key is absent, the user cleared the section -> default it to []
    # so the merge replaces the stored array. Drop the marker so it never lands
    # in the saved doc.
    DELETABLE_ARRAY_SECTIONS = %w[stratigraphies supplements].freeze

    def normalize_deletable_arrays!(repaired)
      DELETABLE_ARRAY_SECTIONS.each do |section|
        next unless repaired.delete("#{section}_present")

        repaired[section] ||= []
      end
    end

    def loci_for_search(query)
      normalized_query = query.delete(' ').upcase
      rows = @db.view('opendig/all_loci')["rows"]

      rows.filter_map do |row|
        label = row["key"].to_s
        area, square, code = label.split('.')
        next unless area.present? && square.present? && code.present? # skips bad data label

        normalized_label = label.upcase
        code_no_leading_zeros = code.sub(/\A0+/, '')
        query_no_leading_zeros = normalized_query.sub(/\A0+/, '')

        matches_label = normalized_label.include?(normalized_query)
        matches_code = code.start_with?(normalized_query)
        matches_unpadded_code = code_no_leading_zeros.present? && query_no_leading_zeros.present? && code_no_leading_zeros.start_with?(query_no_leading_zeros)
        next unless matches_label || matches_code || matches_unpadded_code

        {
          label: label,
          area: area,
          square: square,
          code: code,
          url: area_square_locus_path(area, square, code)
        }
      end.first(50)
    end

    def locus_params
      params.require(:locus).permit!
    end

  # Merge the form params into the CURRENT locus doc without dropping fields the
  # form didn't render (find photos/state, etc. — see LocusMerge), and save with
  # retry-on-conflict: on a 409 (someone else saved meanwhile) re-fetch the doc,
  # re-merge onto it, and try again. Returns the saved doc, or false if it still
  # conflicts after several tries (caller re-renders with a warning rather than
  # 500-ing and losing the edit). CouchRest raises Conflict on 409; it never
  # returns false, so the old `if @db.save_doc` else-branch was dead code.
  def save_locus_with_retry(repaired, attempts: 3)
    existing = @locus
    attempts.times do
      merged = LocusMerge.merge(existing, repaired)
      begin
        @db.save_doc(merged)
        return merged
      rescue CouchRest::Conflict
        existing = refetch_locus(existing['_id'])
        return false unless existing
      end
    end
    false
  end

  def refetch_locus(id)
    @db.get(id)
  rescue CouchRest::Exception
    nil
  end

  def repair_nested_params(obj)
    obj.each do |key, value|
      if value.is_a?(ActionController::Parameters) || value.is_a?(Hash)
        # If any non-integer keys
        if value.keys.find { |k, _| k =~ /\D/ }
          repair_nested_params(value)
        else
          obj[key] = value.values
          value.each_value { |h| repair_nested_params(h) }
        end
      end
    end
  end
end
