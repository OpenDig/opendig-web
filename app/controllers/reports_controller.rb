class ReportsController < ApplicationController
  def index
    @seasons = @db.view('opendig/seasons', { group: true })['rows'].map { |row| row['key'] }.sort.reverse
    @report_types = { 'Artifacts' => 'A', 'Objects' => 'B', 'Samples' => 'S', 'Bone Bag' => 'Z' }
  end

  def show
    @season = params[:id].to_i
    report_type_param = params[:report_type]
    if %w[A B S].include? report_type_param
      case report_type_param
      when 'A'
        @report_type = 'artifacts'
      when 'B'
        @report_type = 'objects'
      when 'S'
        @report_type = 'samples'
      end
      @rows = CsvData.new(@report_type).rows
      # @rows = @db.view('opendig/report', {reduce: false, start_key: [@season, report_type_param], end_key:[@season, report_type_param, {}] })["rows"]
      @rows.select! do |row|
        row.dig('allocation')&.upcase&.include?('DoA'.upcase)
      end.sort_by! { |row| row.dig('registration_number').to_s }
    elsif %w[Z].include? report_type_param
      @report_type = 'bones'
      # @rows = @db.view('opendig/bone_report', {reduce: false, start_key: [@season], end_key:[@season, {}] })["rows"]

      keys = %w[area square locus pail date]
      csv_data = File.read('data/bones.csv')
      @rows = CSV.parse(csv_data).map { |a| Hash[keys.zip(a)] }
      @rows.map do |r|
        r['locus'] = format('%03d', r['locus'].to_i)
        r['pail'] = format('%03d', r['pail'].to_i)
      end

      @rows.sort_by! { |row| [row.dig('area'), row.dig('square'), row.dig('locus'), row.dig('pail')] }
    end

    field_set_selector = @descriptions['reports'][@report_type]['field_set']
    @report_type_title = @descriptions['reports'][@report_type]['title']
    style = @descriptions['reports'][@report_type]['style']
    @field_set = @descriptions['field_sets'][field_set_selector]

    respond_to do |format|
      format.html do
        render template: "reports/show_#{style}"
      end
      format.pdf do
        render pdf: "#{@season}_#{@report_type}_report",
               template: "reports/pdf_#{style}",
               layout: 'pdf', formats: [:html],
               show_as_html: debug?,
               footer: { right: '[page] of [topage]' }
        # disposition: 'attachment'
      end
    end
  end

  protected

  def debug?
    params[:debug].present? && Rails.env == 'development'
  end
end
