class ReportsController < ApplicationController
  before_action :require_authentication

  def index
    @seasons = @db.view('opendig/seasons', { group: true })['rows'].map { |row| row['key'] }.sort.reverse
    @report_types = { 'Artifacts' => 'A', 'Objects' => 'B', 'Samples' => 'S', 'Bone Bag' => 'Z' }
  end

  def show
    @season = params[:id].to_i
    report_type_param = params[:report_type]
    if %w[A B S].include? report_type_param
      @report_type = { 'A' => 'artifacts', 'B' => 'objects', 'S' => 'samples' }[report_type_param]
      # Finalized finds for this season + category, live from CouchDB — replaces
      # the legacy static data/*.csv export.
      @rows = finalized_finds(@season, report_type_param)
      @rows.sort_by! { |row| row['registration_number'].to_s }
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

      @rows.sort_by! { |row| [row['area'], row['square'], row['locus'], row['pail']] }
    end

    report_config = @descriptions['reports'][@report_type]
    field_set_selector = report_config['field_set']
    @report_type_title = report_config['title']
    style = report_config['style']
    @field_set = @descriptions['field_sets'][field_set_selector]

    # Some reports (samples) are broken into sections by a field, e.g. one list
    # per allocation within a single PDF. @grouped is [label, rows] sorted;
    # rows with no value fall under "Unassigned".
    @group_by = report_config['group_by']
    if @group_by
      @grouped = @rows
                 .group_by { |row| row[@group_by].to_s.strip.presence || 'Unassigned' }
                 .sort_by { |label, _| label.downcase }
    end

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

  # A find is "finalized" when the registrar has moved it to the Completed stage.
  FINALIZED_STATE = 'registration complete'.freeze

  # Finalized finds for a season + category (A/B/S), sourced live from the
  # per-project CouchDB via the `opendig/report` view (which emits every find
  # carrying a registration number, keyed by [season, category-letter], with the
  # find's fields — including `state` — merged in). Only Completed-stage finds
  # are kept; the report is empty until finds are finalized in the registrar.
  def finalized_finds(season, type)
    @db.view('opendig/report',
             { reduce: false, start_key: [season, type], end_key: [season, type, {}] })['rows']
       .map { |row| row['value'] }
       .select { |find| find['state'] == FINALIZED_STATE }
  rescue StandardError => e
    Rails.logger.warn("finalized_finds(#{season}, #{type}) failed: #{e.class}: #{e.message}")
    []
  end

  def debug?
    params[:debug].present? && Rails.env == 'development'
  end
end
