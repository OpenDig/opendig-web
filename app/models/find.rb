require 'date'
require "aws-sdk-s3"
require "net/http"

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
    return false if registration_number.upcase.start_with?("S")
    true
  end

  def self.get_image_keys(registration_number)
    Rails.cache.fetch("#{registration_number}_images", expires_in: 1.day) do
      bucket = Rails.application.config.s3_bucket
      object_key = "finds/#{registration_number}"
      objects = bucket.objects(prefix: object_key)
      keys = objects.map(&:key)
      keys
    end
  end

  def self.check_image(registration_number)
    Rails.cache.fetch("#{registration_number}_has_keys", expires_in: 1.day) do
      keys = get_image_keys(registration_number)
      keys.any?
    end
  end

  def self.get_presigned_url(registration_number)
    unless Find.can_have_image?(registration_number)
      url = 'https://via.placeholder.com/250x250.png?text=No+Image'
    else
      bucket = Rails.application.config.s3_bucket
      object_key = "#{registration_number}.jpg"
      if bucket.object(object_key).exists?
        begin
          url = bucket.object(object_key).presigned_url(:get)
        rescue Aws::Errors::ServiceError => e
          Rails.logger.error "Couldn't create presigned URL for #{bucket.name}:#{object_key}. Here's why: #{e.message}"
          url = 'https://via.placeholder.com/250x250.png?text=No+Image'

        end
      else
        url = 'https://via.placeholder.com/250x250.png?text=No+Image'
      end
    end

    url
  end
end