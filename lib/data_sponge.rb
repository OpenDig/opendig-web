module DataSponge
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
    def area
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
      "#{area}.#{square}.#{locus_code}"
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
        field_number: field_number,
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

  def self.find_matches_for(file, missing)
    puts "Processing #{file}..."
    File.open("data/#{file}.csv").each do |l|
      line = l.chomp.split(',', -1)
      find = DataLine.new(*line[0..31])
      unless find.locus && find.field_number && find.pail_number
        present_locus = find.locus.present? ? 'present' : 'missing'
        present_pail = find.pail_number.present? ? 'present' : 'missing'
        present_field_number = find.field_number.present? ? 'present' : 'missing'
        missing << "#{find.registration_number},#{present_locus},#{present_pail},#{present_field_number}"
        next
      end
      next if item = @items.select { |item| item.formatted_locus_code == find.locus }
                           &.select { |item| item.field_number.to_i == find.field_number.to_i }
                           &.select { |item| item.pail_number.to_i == find.pail_number.to_i }&.first

      found_locus = 'Matched' if @items.select { |item| item.formatted_locus_code == find.locus }.present?
      found_pail = 'Matched in Square' if @items.select do |item|
        item.area == find.area && item.square == find.square && item.pail_number.to_i == find.pail_number.to_i
      end.present?
      found_field_number = 'Matched in Square' if @items.select do |item|
        item.area == find.area && item.square == find.square && item.field_number.to_i == find.field_number.to_i
      end.present?
      missing << "#{find.registration_number},#{found_locus || 'Unmatched'},#{found_pail || 'Unmatched'},#{found_field_number || 'Unmatched'}"
    end
  end

  def self.update_data_for(file)
    puts "Processing #{file}..."
    File.open("data/#{file}.csv").each do |l|
      line = l.chomp.split(',', -1)
      find = DataLine.new(*line[0..31])
      next unless find.locus && find.field_number && find.pail_number

      if item = @items.select { |item| item.formatted_locus_code == find.locus }
                      &.select { |item| item.field_number.to_i == find.field_number.to_i }
                      &.select { |item| item.pail_number.to_i == find.pail_number.to_i }&.first
        doc = @db.get(item.id)
        pails = doc['pails']
        pail = pails.find { |pail| pail['pail_number'].to_i == find.pail_number.to_i }
        finds = pail['finds']
        _find = finds.find { |f| f['field_number'].to_i == find.field_number.to_i }
        _find.merge!(find.hash_to_merge)
        if doc.save
          puts 'Saved!'
        else
          puts 'Failed to save'
        end
      else
        puts "#{find.registration_number}: No match for Locus #{find.locus}, field number #{find.field_number} in pail #{find.pail_number}, creating new record for find"
        if locus = @db.view('opendig/locus',
                            key: [find.area, find.square, find.locus_code])['rows']&.first&.dig('value')
          doc = @db.get(locus['_id'])
          pails = doc['pails']
          pail = pails.find { |pail| pail['pail_number'].to_i == find.pail_number.to_i }
          pail['finds'] << find.hash_to_merge
          if doc.save
            puts 'Saved!'
          else
            puts 'Failed to save'
          end
        else
          puts "No match for Locus #{find.locus}"
        end
      end
      Find.clear_cache_keys(find.registration_number)
    end
  end

  def self.sponge(files = nil)
    @db = Rails.application.config.couchdb
    @items = Registrar.all_by_season(2022)
    files ||= %w[objects samples artifacts]
    files = Array(files)
    files.each do |item|
      missing = []
      find_matches_for(item, missing)
      File.open("data/unmatched_#{item}.csv", 'w') do |file|
        file.puts 'Registration Number, Locus, Pail, Field Number'
        missing.each { |find| file.puts find }
      end
    end
  end

  def self.update_data(files = nil)
    @db = Rails.application.config.couchdb
    @items = Registrar.all_by_season(2022)
    files ||= %w[objects samples artifacts]
    files = Array(files)
    files.each do |item|
      update_data_for(item)
    end
  end
end
