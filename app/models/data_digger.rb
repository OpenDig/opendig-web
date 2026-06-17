class DataDigger
  def self.age
    @descriptions = Rails.application.config.descriptions
    @descriptions['lookups']['age']
  end

  def self.stratigraphy_related_how
    [
      'Abuts',
      'Abutted by',
      'Bonded to',
      'Contiguous to',
      'Cut by',
      'Cuts',
      'Equals',
      'Fill Loci',
      'FT',
      'Installation',
      'Over',
      'Sealed agnst by',
      'Seals against',
      'Under'
    ]
  end

  def self.stratigraphy_related_type
    [
      'Bedrock',
      'Cistern',
      'Earth layer',
      'FT',
      'Other',
      'Pit',
      'Surface',
      'Wall',
      'Installation'
    ]
  end

  def self.survey_instruments
    [
      'GPS',
      'Total Station'
    ]
  end
end
