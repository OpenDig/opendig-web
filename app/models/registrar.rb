class Registrar

  attr_accessor :locus, :pail_number, :field_number, :type, :remarks, :id

  def initialize(row_values)
    @locus, @pail_number, @field_number, @type, @remarks, @id = row_values
  end

  def to_ary
    [locus, pail_number, field_number, type, remarks, id]
  end

  def self.all_by_season(season)
    rows = []
    Rails.application.config.couchdb.view('opendig/registrar', {keys: [season], reduce: false})['rows'].map do |row|
      rows << Registrar.new(row['value'])
    end
    rows
  end

end