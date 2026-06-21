class Registrar
  attr_accessor :code, :pail_number, :field_number, :registration_number, :type, :remarks, :id, :state, :square, :area

  # The registration pipeline, in order. Each find sits in exactly one stage,
  # derived from its stored `state`. Labels are what the registrar page shows;
  # `states` lists the raw state values that map into the stage. Field finds
  # synced from devices have no state yet, so they land in "Incoming".
  STAGES = [
    { key: 'incoming',  label: 'Incoming',             states: %w[unregistered] },
    { key: 'initial',   label: 'Initial Registration', states: ['initial registration'] },
    { key: 'pending',   label: 'Pending Approval',     states: %w[WIP] },
    { key: 'completed', label: 'Completed',            states: ['registrarion complete'] }
  ].freeze

  def initialize(row_values)
    @area, @square, @code, @pail_number, @field_number, @registration_number, @type, @remarks, @state, @id = row_values
    @state = 'unregistered' unless @state.present?
  end

  # The pipeline stage key for this find. Any unrecognised state falls into the
  # first stage so nothing silently disappears from the board.
  def stage
    STAGES.find { |s| s[:states].include?(state) }&.fetch(:key) || STAGES.first[:key]
  end

  def to_ary
    [locus, pail_number, field_number, type, remarks, id, state]
  end

  def full_locus_code
    "#{area}.#{square}.#{code}"
  end

  def formatted_locus_code
    "#{area}.#{square}.#{format('%03d', code.to_i)}"
  end

  def self.all_by_season(season)
    rows = []
    CouchDB.main_db.view('opendig/registrar', {keys: [season], reduce: false})['rows'].map do |row|
      rows << Registrar.new(row['value'])
    end
    rows
  end

  #   def self.import_csv(filename)
  #     FindStruct = Struct.new( :registration_number, :field_number, :site, :square, :locus, :pail, :cu_or_bt, :gps_id, :designation, :certainty, :period, :stratum, :modifier_1, :modifier_2, :shape, :shape_modifier, :material, :color, :preservation, :percent, :craftsmanship, :decoration, :weight, :lg_ht, :width, :thickness, :diam, :perf_diam, :condition, :pieces, :allocation, :comments, :drawing, :drawing_date, :artist, :photo_file_names, :photo_date, :photographer, :parallels, :parallel_notes, :xrf, :three_d_scan, :rti, :residue_analysis, :conserved_restored ) # rubocop:disable Layout/LineLength

  # # "technique"
  # # "munsell"
  # # "preservation"
  # # "preservation_percent"
  # # "craftsmanship"
  # # "decoration"
  # # "weight"
  # # "length_height"
  # # "width"
  # # "thickness"
  # # "diameter"
  # # "perforation_diameter"
  # # "registars_condition"
  # # "pieces"
  # # "allocation"
  # # "notes"
  # # "state"

  #     finds = []

  #     file = File.open(filename, 'r')
  #     file.each_line do |line|
  #       row = line.split("\t")
  #       next if row[0] == 'Regis #'
  #       find = FindStruct.new(*row)
  #       finds << find
  #     end

  #     finds.each do |find|
  #       @couchdb.view('opendig/registrar', {keys: [find.registration_number], reduce: false})['rows'].map do |row|
  #       end
  #     end
  #   end
end
