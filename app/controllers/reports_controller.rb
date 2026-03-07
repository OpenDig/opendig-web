# ReportsController is responsible for generating reports based on the data in the database.
# It allows users to see available seasons and report types. It provides selected reports
# in HTML or PDF format. The controller also includes a debug mode for development purposes.
class ReportsController < ApplicationController
  def index
    @seasons = @db.view('opendig/seasons', { group: true })['rows'].map { |row| row['key'] }.sort.reverse # rubocop:disable Rails/Pluck
    @report_types = { 'Artifacts' => 'A', 'Objects' => 'B', 'Samples' => 'S', 'Bone Bag' => 'Z' }
  end

  def show
    @season = params[:id].to_i
    @report_type = @report_types.invert[params[:report_type]].downcase

    grab_report_data
    style = process_report_data

    respond_to do |format|
      format.html { render template: "reports/show_#{style}" }
      format.pdf { render_pdf_report(style) }
    end
  end

  protected

  def grab_report_data
    if @report_type == 'Z'
      grab_bone_report_data
    else
      @rows = CsvData.new(@report_type).rows
      # @rows = @db.view('opendig/report',
      #                  {reduce: false,
      #                   start_key: [@season, report_type_param],
      #                   end_key:[@season, report_type_param, {}]
      #                  }
      #                 )["rows"]
      @rows.select! { |row| row['allocation']&.upcase&.include?('DoA'.upcase) }
           .sort_by! { |row| row['registration_number'].to_s }
    end
  end

  def grab_bone_report_data
    # @rows = @db.view('opendig/bone_report', {reduce: false, start_key: [@season], end_key:[@season, {}] })["rows"]

    keys = %w[area square locus pail date]
    csv_data = File.read('data/bones.csv')
    @rows =  CSV.parse(csv_data).map { |a| keys.zip(a).to_h }
    process_bone_report_data
  end

  def process_bone_report_data
    @rows.map do |r|
      r['locus'] = format('%03d', r['locus'].to_i)
      r['pail'] = format('%03d', r['pail'].to_i)
    end
    @rows.sort_by! { |row| [row['area'], row['square'], row['locus'], row['pail']] }
  end

  def process_report_data
    field_set_selector = @descriptions['reports'][@report_type]['field_set']
    @report_type_title = @descriptions['reports'][@report_type]['title']
    style = @descriptions['reports'][@report_type]['style']
    @field_set = @descriptions['field_sets'][field_set_selector]
    style
  end

  def render_pdf_report(style)
    render  pdf: "#{@season}_#{@report_type}_report",
            template: "reports/pdf_#{style}",
            layout: 'pdf', formats: [:html],
            show_as_html: debug?,
            footer: { right: '[page] of [topage]' }
    # disposition: 'attachment'
  end

  def debug?
    params[:debug].present? && Rails.env.development?
  end
end
