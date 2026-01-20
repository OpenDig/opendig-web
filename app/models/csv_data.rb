require 'csv'

class CsvData
  attr_accessor :rows

  def initialize(csv_file)
    keys = 'registration_number,field_number,site,square,locus,pail_number,cu_bt,gis_id,designation,certainty,period,stratum,modifier_1,modifier_2,shape,shape_modifier,material,color,preservatin,percent,craftsmanship,decoration,weight,length,width,thickness,diam,perforation,condition,pieces,allocation,comments,drawing,drawing_date,Artist,Photo File Names,Photo Date,Photographer,Parallels,Parallel Notes,XRF,3D Scan,RTI,Residue Analysis,Conserved/Restored,,,,'.split(',')
    csv_data = File.read("data/#{csv_file}.csv")
    raw_data = CSV.parse(csv_data).map { |a| Hash[keys.zip(a)] }
    raw_data.map do |row|
      area = row['square']&.split('.')&.first
      square = row['square']&.split('.')&.last
      row['area'] = area
      row['square'] = square
      row['season'] = 2022
    end

    @rows = raw_data
  end
end
