require 'date'
require 'aws-sdk-s3'
require 'net/http'

class Find
  attr_accessor :locus, :pail_number, :pail_date, :field_number, :type, :remarks, :id, :season, :gis_id

  def initialize(row)
    @locus, @pail_number, @pail_date, @field_number, @type, @remarks, @gis_id, @id = row
    @season = Date.parse(@pail_date)&.year || nil
  end

  def to_ary
    [locus, pail_number, pail_date, field_number, type, remarks, gis_id, id]
  end

  def self.can_have_image?(registration_number)
    return unless registration_number.present?
    return false if registration_number.upcase.start_with?('S')

    true
  end

  def self.get_image_keys(registration_number)
    Rails.cache.fetch("#{registration_number}_images", expires_in: 5.minutes) do
      bucket = Rails.application.config.s3_bucket
      object_key = "finds/#{registration_number}"
      objects = bucket.objects(prefix: object_key)
      keys = objects.map(&:key)
      keys
    end
  end

  def self.check_image(registration_number)
    Rails.cache.fetch("#{registration_number}_has_keys", expires_in: 5.minutes) do
      keys = get_image_keys(registration_number)
      keys.any?
    end
  end

  def self.get_presigned_urls(registration_number)
    bucket = Rails.application.config.s3_bucket

    if Find.can_have_image?(registration_number)
      Rails.cache.fetch("#{registration_number}_presigned_urls", expires_in: 5.minutes) do
        keys = get_image_keys(registration_number)
        urls = keys.map do |key|
          find_url(key)
          bucket.object(key).presigned_url(:get)
        end
        urls
      end
    else
      ['https://via.placeholder.com/250x250.png?text=No+Image']
    end
  end

  def self.url(key, style = :original)
    Rails.cache.fetch("#{key}_url_#{style}", expires_in: 1.hour) do
      photo_style = Photo.styles(style)
      builder = Imgproxy::Builder.new(
        photo_style.transform_keys(&:to_sym)
      )
      builder.url_for("s3://#{Rails.application.config.s3_bucket.name}/#{key}")
    end
  end

  def self.clear_cache_keys(registration_number)
    Rails.cache.delete("#{registration_number}_images")
    Rails.cache.delete("#{registration_number}_has_keys")
    Rails.cache.delete("#{registration_number}_presigned_urls")
  end
end
