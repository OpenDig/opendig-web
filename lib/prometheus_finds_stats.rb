# Text collector stats
module PrometheusFindsStats
  DataLine = Struct.new(
    :registration_number,
    :field_number,
    :site_code,
    :square_code,
    :locus_code_raw,
    :pail_number,
    :cu_bt,
    :gis_id,
    :designation,
    :certainty,
    :period,
    :stratum,
    :modifier_1,
    :modifier_2,
    :shape,
    :shape_modifier,
    :material,
    :color,
    :preservation,
    :percent,
    :craftsmanship,
    :decoration,
    :weight,
    :length_height,
    :width,
    :thickness,
    :diameter,
    :perforation_diameter,
    :registars_condition,
    :pieces,
    :allocation,
    :notes
  ) do
    def field
      square_code.split('.')&.first
    end

    def square
      code = square_code.split('.')&.last
      if code&.length == 1
        "#{code}0"
      else
        code
      end
    end

    def locus
      "#{field}.#{square}.#{locus_code}"
    end

    def locus_code
      if locus_code_raw.present?
        format('%03d', locus_code_raw.to_i)
      else
        nil
      end
    end

    def site
      site_code || 'B'
    end

    def hash_to_merge
      {
        registration_number: registration_number,
        designation: designation,
        certainty: certainty,
        period: period,
        stratum: stratum,
        modifier_1: modifier_1,
        modifier_2: modifier_2,
        shape: shape,
        shape_modifier: shape_modifier,
        material: material,
        color: color,
        preservation: preservation,
        percent: percent,
        craftsmanship: craftsmanship,
        decoration: decoration,
        weight: weight,
        length_height: length_height,
        width: width,
        thickness: thickness,
        diameter: diameter,
        perforation_diameter: perforation_diameter,
        registars_condition: registars_condition,
        pieces: pieces,
        allocation: allocation,
        notes: notes,
        state: 'initial registration'
      }.stringify_keys
    end
  end

  def self.find_matches_for(file, missing, missing_photos)
    puts "Processing #{file}..."
    File.open("data/#{file}.csv").each do |l|
      line = l.chomp.split(',', -1)
      find = DataLine.new(*line[0..31])
      unless find.locus && find.field_number && find.pail_number
        missing << "#{find.registration_number}"
        next
      end
      missing_photos << find.registration_number if file != 'samples' && !Find.check_image(find.registration_number)
      next if @items.select do |item|
        item.formatted_locus_code == find.locus && item.field_number.to_i == find.field_number.to_i && item.pail_number.to_i == find.pail_number.to_i
      end.present?

      missing << "#{find.registration_number}"
    end
  end

  def self.gather_stats
    @db = Rails.application.config.couchdb

    loop do
      @items = Registrar.all_by_season(2022)
      file = File.open('shared-data/textfile_collector/missing_opendig.prom', 'w')
      file.puts "\#HELP Current number of missing matches for OpenDig field finds"
      file.puts "\#TYPE missing_opendig_count gauge"
      %w[objects samples artifacts].each do |item|
        missing = []
        missing_photos = []
        find_matches_for(item, missing, missing_photos)
        file.puts "missing_opendig_count{find_type=\"#{item}\"} #{missing.count}"
        puts "#{item} missing: #{missing.count}"
        file.puts "missing_opendig_count{find_type=\"#{item}_photos\"} #{missing_photos.count}"
        puts "#{item}_photos missing: #{missing_photos.count}"
        missing_photo_file = File.open("data/missing_#{item}_photos", 'w')
        missing_photo_file.puts missing_photos.join("\n")
        missing_photo_file.close
      end
      file.close
      sleep(60)
    end
  end
end
