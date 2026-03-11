class LociController < ApplicationController
  before_action :set_locus, only: [:show, :edit, :update]
  def index
    @area = params[:area_id]
    @square = params[:square_id]
    @loci = @db.view('opendig/loci', {group: true, start_key: [@area, @square], end_key: [@area, @square, {}]})["rows"].map{|row| Locus.new(row["key"])}
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

  def edit
  end

  def new
    @area = params[:area_id]
    @square = params[:square_id]
    @locus = {"locus_type" => params[:type]}
  end

  def update
    locus_params = params[:locus].to_enum.to_h
    locus_params = repair_nested_params(locus_params)
    locus_params = @locus.deep_merge(locus_params)

    if @db.save_doc(locus_params)
      flash[:success] = "Success! Locus Updated"
      redirect_to area_square_locus_path(@area, @square, locus_params['code'])
    else
      flash.now[:error] = "Something went wrong"
      render :edit
    end
  end

  def create
    new_locus = params[:locus]
    if @db.save_doc(new_locus)
      flash[:success] = "Success! New Locus Created"
      redirect_to area_square_loci_path(params[:area_id], params[:square_id])
    else
      flash.now[:error] = "Something went wrong"
      render :new
    end

  end

  private
    def set_locus
      @area = params[:area_id]
      @square = params[:square_id]
      @locus_code = params[:id]
      @locus = @db.view('opendig/locus', key: [@area, @square, @locus_code])["rows"]&.first&.dig("value")
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
      parameters.require(:locus).permit!
    end

    def repair_nested_params(obj)
      obj.each do |key, value|
        if value.is_a?(ActionController::Parameters) || value.is_a?(Hash)
          # If any non-integer keys
          if value.keys.find {|k, _| k =~ /\D/ }
            repair_nested_params(value)
          else
            obj[key] = value.values
            value.values.each {|h| repair_nested_params(h) }
          end
        end
      end
    end
end
