module ApplicationHelper
  # Normalize an embedded collection (pails, readings, finds) into an array of
  # hashes for iteration. Most docs store these as an array, but some legacy
  # docs store them as a Hash keyed by id -- iterating that yields [key, value]
  # pairs and blows up on item['field']. Coerce both shapes and drop non-hashes.
  def hash_rows(collection)
    rows = collection.is_a?(Hash) ? collection.values : collection
    Array(rows).select { |row| row.is_a?(Hash) }
  end

  # A field-note ("user") photo vs an official daily photo. Field notes are
  # tagged with a type by the device ('user_photo'; legacy 'field_note').
  def field_note_photo?(photo)
    %w[user_photo field_note].include?(photo['type'].to_s)
  end

  # Every field-note photo for a locus: the dedicated user_photos[] array plus
  # any photos[] entries the device tagged as field notes (the mobile app writes
  # field notes into photos[]).
  def field_note_photos(locus)
    hash_rows(locus['user_photos']) + hash_rows(locus['photos']).select { |p| field_note_photo?(p) }
  end

  # Official photos only: photos[] entries that aren't field notes.
  def official_photos(locus)
    hash_rows(locus['photos']).reject { |p| field_note_photo?(p) }
  end

  # Assemble an artifact (find)'s photos for display, de-duped by key:
  #   - official images discovered by the registration-number bucket prefix
  #     (the registrar's catalogue uploads), kept as-is, type 'official';
  #   - the find's own photos[] entries (official or note), which take
  #     precedence over a prefix-derived entry with the same key so their
  #     type/metadata wins;
  #   - the legacy single photo_key (a field note from older mobile builds).
  def find_photos(find)
    by_key = {}
    reg = find['registration_number']
    Find.get_image_keys(reg).each { |k| by_key[k] = { 'key' => k, 'type' => 'official' } } if Find.can_have_image?(reg)
    hash_rows(find['photos']).each do |p|
      by_key[p['key']] = p if p['key'].present?
    end
    legacy = find['photo_key']
    by_key[legacy] ||= { 'key' => legacy, 'type' => 'user_photo' } if legacy.present?
    by_key.values
  end

  # The key of the find's cover (main) photo: the stored cover_key if it still
  # points at a present photo, else the first official, else the first photo.
  def find_cover_key(find, photos = find_photos(find))
    explicit = find['cover_key']
    return explicit if explicit.present? && photos.any? { |p| p['key'] == explicit }

    (photos.find { |p| !field_note_photo?(p) } || photos.first)&.dig('key')
  end

  # Always begin the OAuth handshake on the apex domain (opendig.org), so the
  # provider (Google) needs only one registered redirect URI instead of one per
  # subdomain. The `origin` carries the user back to the subdomain they started
  # on; the shared session cookie (see config/initializers/session_store.rb)
  # keeps them logged in there.
  def oauth_start_url(provider, origin: oauth_return_origin)
    "#{oauth_apex_base}/auth/#{provider}?origin=#{CGI.escape(origin)}"
  end

  # Scheme + apex host (registrable domain), preserving a non-default port in dev.
  def oauth_apex_base
    host = request.domain.presence || request.host
    host = "#{host}:#{request.port}" unless request.port == (request.ssl? ? 443 : 80)
    "#{request.scheme}://#{host}"
  end

  # Where to send the user after login: the root of the host they're on now.
  def oauth_return_origin
    "#{request.scheme}://#{request.host_with_port}/"
  end

  def stratigraphic_relationships
    DataDigger.stratigraphy_related_how
  end

  def stratigraphy_relatation_types
    DataDigger.stratigraphy_related_type
  end

  def all_loci
    Locus.all
  end

  def survey_instruments
    DataDigger.survey_instruments
  end

  def pot_form
    Rails.application.config.descriptions['lookups']['pot_form']
  end

  def age
    Rails.application.config.descriptions['lookups']['age']
  end

  def time_level
    Rails.application.config.descriptions['lookups']['time_level']
  end

  def question
    Rails.application.config.descriptions['lookups']['question']
  end

  def sanitize_locus(locus)
    locus&.gsub(/\D/, '.')
  end

  # def flash_class(level)
  #   case level
  #   when :notice then "alert alert-info"
  #   when :success then "alert alert-success"
  #   when :error then "alert alert-error"
  #   when :alert then "alert alert-error"
  #   end
  # end

  # This will assign the correct bootstrap colors to the messages
  def flash_class(name)
    case name
    when 'notice' then 'alert alert-info alert-dismissable fade show'
    when 'success' then 'alert alert-success alert-dismissable fade show'
    when 'error' then 'alert alert-danger alert-dismissable fade show'
    when 'alert' then 'alert alert-danger alert-dismissable fade show'
    else
      'alert alert-primary alert-dismissable fade show'
    end
  end

  # Exlude these messages from appearing
  def flash_blacklist(name)
    %w[timedout].include?(name)
  end

  def level_or_nil(level)
    if level == '0' || nil
      '-'
    else
      level
    end
  end

  # Day-granularity dates only — never a timestamp. Renders clearly, e.g.
  # "24 June, 2026". Falls back to the raw value if it can't be parsed so a bad
  # date string never 500s a page.
  def read_date(date_string)
    return if date_string.blank?

    Date.parse(date_string.to_s).strftime('%-d %B, %Y')
  rescue ArgumentError, TypeError
    date_string
  end

  # Normalize any stored date or timestamp to YYYY-MM-DD for a native
  # <input type="date">. Returns '' when unparseable so the picker isn't left in
  # a broken state.
  def iso_date(date_string)
    return '' if date_string.blank?

    Date.parse(date_string.to_s).strftime('%Y-%m-%d')
  rescue ArgumentError, TypeError
    ''
  end

  def output(value, type)
    case type
    when 'date'
      read_date value if value
    else
      value
    end
  end

  def input_for(form_definition_hash, value, description_type)
    name = "locus[#{description_type}][#{form_definition_hash['key']}]"
    case form_definition_hash['type']
    # 'munsel_picker' (the Munsell colour list) is just a picker with inline values.
    when 'picker', 'munsel_picker'
      options = if form_definition_hash['values'].is_a?(Hash)
                  @descriptions['lookups'][form_definition_hash['values']['from']]
                else
                  form_definition_hash['values']
                end
      select_tag name, options_for_select(options || [], value), include_blank: true, class: 'form-control'
    when 'checkbox'
      check_box_tag name, true, ActiveModel::Type::Boolean.new.cast(value), class: 'form-control'
    when 'text_area'
      text_area_tag name, value, class: 'form-control'
    # text_field, date, and any missing/unknown type fall back to a text input so
    # a field never silently disappears (was the case for nil-typed fields).
    else
      text_field_tag name, value, class: 'form-control'
    end
  end

  # supplement_type => description field-set it reuses (architecture_description, etc.)
  def supplement_types
    @descriptions['supplements'] || {}
  end

  # Renders one supplement field, scoped to a specific supplement row index so
  # each supplement is an independent hash in locus[supplements]. Mirrors
  # input_for but with explicit array indices (locus[supplements][i][key]) so
  # heterogeneous supplement types don't get column-zipped together.
  def supplement_input_for(entry, value, index)
    name = "locus[supplements][#{index}][#{entry['key']}]"
    case entry['type']
    when 'picker', 'munsel_picker'
      options = if entry['values'].is_a?(Hash)
                  @descriptions['lookups'][entry['values']['from']]
                else
                  entry['values']
                end
      select_tag name, options_for_select(options || [], value), include_blank: true, class: 'form-control'
    when 'checkbox'
      hidden_field_tag(name, '0', id: nil) +
        check_box_tag(name, '1', ActiveModel::Type::Boolean.new.cast(value), class: 'form-control')
    when 'text_area'
      text_area_tag name, value, rows: 3, class: 'form-control'
    when 'date'
      text_field_tag name, value, type: 'date', class: 'form-control'
    else
      text_field_tag name, value, class: 'form-control'
    end
  end

  def input_with_full_param_name(form_definition_hash, value, full_param_name)
    puts "input_with_full_param_name: #{form_definition_hash.inspect}"

    case form_definition_hash['type']
    when 'picker'
      if form_definition_hash['values'].is_a? Hash
        select_tag(
          full_param_name.to_s,
          options_for_select(@descriptions['lookups'][form_definition_hash['values']['from']], value),
          include_blank: true,
          class: 'form-control'
        )
      else
        select_tag(
          full_param_name.to_s,
          options_for_select(form_definition_hash['values'], value),
          include_blank: true,
          class: 'form-control'
        )
      end
    when 'text_field'
      text_field_tag full_param_name.to_s, value, class: 'form-control'
    when 'date'
      # Native date picker; day-granularity only (strips any stored timestamp).
      text_field_tag full_param_name.to_s, iso_date(value), type: 'date', class: 'form-control'
    when 'checkbox'
      check_box_tag full_param_name.to_s, true, false, class: 'form-control'
    when 'text_area'
      text_area_tag full_param_name.to_s, value, class: 'form-control'
    end
  end
end
