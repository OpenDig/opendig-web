require 'date'
require 'erb'
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
    bucket = Rails.application.config.try(:s3_bucket)
    return [] if bucket.nil?

    Rails.cache.fetch("#{ProjectStorage.storage_project}/#{registration_number}_images", expires_in: 5.minutes) do
      object_key = "#{ProjectStorage.finds_prefix}/#{registration_number}"
      bucket.objects(prefix: object_key).map(&:key)
    end
  rescue StandardError => e
    Rails.logger.warn("Find.get_image_keys failed for #{registration_number}: #{e.class}: #{e.message}")
    []
  end

  # Warm the per-find image-key cache for a whole report in ONE S3 listing
  # instead of a LIST per find. The report calls image_urls for every row, and a
  # cold cache meant ~N sequential S3 list calls before the PDF even started
  # rendering — the main source of slow report generation. Groups every object
  # under finds/ by find (same prefix match as get_image_keys) and primes each
  # find's cache entry, so the subsequent image_urls calls are cache hits.
  def self.prime_image_keys!(registration_numbers)
    bucket = Rails.application.config.try(:s3_bucket)
    return if bucket.nil?

    regs = Array(registration_numbers).map { |r| r.to_s.strip }.reject(&:empty?).uniq
    regs.select! { |reg| can_have_image?(reg) }
    return if regs.empty?

    all_keys = bucket.objects(prefix: "#{ProjectStorage.finds_prefix}/").map(&:key)
    regs.each do |reg|
      keys = all_keys.select { |k| k.start_with?("#{ProjectStorage.finds_prefix}/#{reg}") }
      Rails.cache.write("#{ProjectStorage.storage_project}/#{reg}_images", keys, expires_in: 5.minutes)
    end
  rescue StandardError => e
    Rails.logger.warn("Find.prime_image_keys! failed: #{e.class}: #{e.message}")
  end

  def self.check_image(registration_number)
    Rails.cache.fetch("#{ProjectStorage.storage_project}/#{registration_number}_has_keys", expires_in: 5.minutes) do
      get_image_keys(registration_number).any?
    end
  end

  # Self-contained SVG data URI — never an external host. wkhtmltopdf fetches
  # every image while rendering a report; an external placeholder (e.g. a dead
  # via.placeholder.com) would hang or fail the whole PDF, so keep it inline.
  NO_IMAGE_SVG =
    '<svg xmlns="http://www.w3.org/2000/svg" width="250" height="250">' \
    '<rect width="250" height="250" fill="#f1e9d8"/>' \
    '<text x="125" y="130" font-family="sans-serif" font-size="18" fill="#9c8e78" ' \
    'text-anchor="middle">No image</text></svg>'.freeze
  NO_IMAGE_PLACEHOLDER = "data:image/svg+xml,#{ERB::Util.url_encode(NO_IMAGE_SVG)}".freeze

  # Imgproxy URL for a find's representative (first) image at the given style, or
  # the placeholder when it has none. Use wherever a single find image is shown
  # (reports, lists) so a resized image is served — never the full original.
  def self.image_url(registration_number, style = :medium)
    return NO_IMAGE_PLACEHOLDER unless can_have_image?(registration_number)

    key = get_image_keys(registration_number).first
    key ? url(key, style) : NO_IMAGE_PLACEHOLDER
  end

  # Imgproxy URLs for EVERY image a find has (e.g. A220168.jpg AND A220168b.jpg,
  # discovered together by S3 prefix), at the given style. Empty when it has
  # none — callers render nothing rather than a placeholder. Use in reports/
  # galleries that should show all photos, not just the representative one.
  def self.image_urls(registration_number, style = :medium)
    return [] unless can_have_image?(registration_number)

    get_image_keys(registration_number).map { |key| url(key, style) }
  end

  def self.url(key, style = :original)
    bucket = Rails.application.config.try(:s3_bucket)
    return Photo.placeholder_url(style) if bucket.nil?

    Rails.cache.fetch("#{key}_url_#{style}", expires_in: 1.hour) do
      builder = Imgproxy::Builder.new(Photo.styles(style).transform_keys(&:to_sym))
      builder.url_for("s3://#{bucket.name}/#{key}")
    end
  end

  def self.clear_cache_keys(registration_number)
    prefix = ProjectStorage.storage_project
    Rails.cache.delete("#{prefix}/#{registration_number}_images")
    Rails.cache.delete("#{prefix}/#{registration_number}_has_keys")
  end
end
