class Registrar
  attr_accessor :code, :pail_number, :field_number, :registration_number, :type, :remarks, :id, :state, :square, :area

  def initialize(row_values)
    @area, @square, @code, @pail_number, @field_number, @registration_number, @type, @remarks, @state, @id = row_values
    @state = 'unregistered' unless @state.present?
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
    Rails.application.config.couchdb.view('opendig/registrar', { keys: [season], reduce: false })['rows'].map do |row|
      rows << Registrar.new(row['value'])
    end
    rows
  end

  #   def self.import_csv(filename)
  #     FindStruct = Struct.new( :registration_number, :field_number, :site, :square, :locus, :pail, :cu_or_bt, :gps_id, :designation, :certainty, :period, :stratum, :modifier_1, :modifier_2, :shape, :shape_modifier, :material, :color, :preservation, :percent, :craftsmanship, :decoration, :weight, :lg_ht, :width, :thickness, :diam, :perf_diam, :condition, :pieces, :allocation, :comments, :drawing, :drawing_date, :artist, :photo_file_names, :photo_date, :photographer, :parallels, :parallel_notes, :xrf, :three_d_scan, :rti, :residue_analysis, :conserved_restored )

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
