module ApplicationHelper
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
    locus.gsub(/\D/, '.') if locus
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

  def read_date(date_string)
    if date_string.present?
      Date.parse(date_string).strftime('%d %b, %Y')
    else
      nil
    end
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
    case form_definition_hash['type']
    when 'picker'
      if form_definition_hash['values'].is_a? Hash
        select_tag "locus[#{description_type}][#{form_definition_hash['key']}]",
                   options_for_select(@descriptions['lookups'][form_definition_hash['values']['from']], value), include_blank: true, class: 'form-control'
      else
        select_tag "locus[#{description_type}][#{form_definition_hash['key']}]",
                   options_for_select(form_definition_hash['values'], value), include_blank: true, class: 'form-control'
      end
    when 'text_field'
      text_field_tag "locus[#{description_type}][#{form_definition_hash['key']}]", value, class: 'form-control'
    when 'date'
      text_field_tag "locus[#{description_type}][#{form_definition_hash['key']}]", value, class: 'form-control'
    when 'checkbox'
      check_box_tag "locus[#{description_type}][#{form_definition_hash['key']}]", true, false, class: 'form-control'
    when 'text_area'
      text_area_tag "locus[#{description_type}][#{form_definition_hash['key']}]", value, class: 'form-control'
    end
  end

  def input_with_full_param_name(form_definition_hash, value, full_param_name)
    puts "input_with_full_param_name: #{form_definition_hash.inspect}"

    case form_definition_hash['type']
    when 'picker'
      if form_definition_hash['values'].is_a? Hash
        select_tag "#{full_param_name}",
                   options_for_select(@descriptions['lookups'][form_definition_hash['values']['from']], value), include_blank: true, class: 'form-control'
      else
        select_tag "#{full_param_name}", options_for_select(form_definition_hash['values'], value),
                   include_blank: true, class: 'form-control'
      end
    when 'text_field'
      text_field_tag "#{full_param_name}", value, class: 'form-control'
    when 'date'
      text_field_tag "#{full_param_name}", value, class: 'form-control'
    when 'checkbox'
      check_box_tag "#{full_param_name}", true, false, class: 'form-control'
    when 'text_area'
      text_area_tag "#{full_param_name}", value, class: 'form-control'
    end
  end
end
