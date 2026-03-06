class LociController < ApplicationController
  before_action :require_editor, except: [:index, :show]
  before_action :set_locus, only: [:show, :edit, :update]
  def index
    @area = params[:area_id]
    @square = params[:square_id]
    @loci = @db.view('opendig/loci', {group: true, start_key: [@area, @square], end_key: [@area, @square, {}]})["rows"].map{|row| Locus.new(row["key"])}
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