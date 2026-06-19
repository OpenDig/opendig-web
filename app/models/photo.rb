class Photo
  def self.styles(style)
    {
      medium: {
        height: 1000,
        width: 1000
      },
      thumb: {
        height: 100,
        width: 100
      },
      original: {}
    }[style]
  end

  # Placeholder shown when an image is missing or the object store is unavailable
  # (no bucket configured, bad credentials, network error) so a page never 500s
  # over a photo.
  def self.placeholder_url(style)
    photo_style = styles(style) || {}
    "https://placehold.jp/#{photo_style[:height] || 1000}x#{photo_style[:width] || 1000}.jpg?text=No+Image"
  end

  def self.photo_exists?(number)
    bucket = Rails.application.config.try(:s3_bucket)
    return false if bucket.nil?

    Rails.cache.fetch "#{ProjectStorage.daily_photos_prefix}/#{number}_exists" do
      bucket.object("#{ProjectStorage.daily_photos_prefix}/#{number}.JPG").exists?
    end
  rescue StandardError => e
    Rails.logger.warn("Photo.photo_exists? failed for #{number}: #{e.class}: #{e.message}")
    false
  end

  def self.photo_url(number, style)
    Rails.cache.fetch "#{ProjectStorage.daily_photos_prefix}/photo_url_#{number}_#{style}" do
      if photo_exists?(number)
        builder = Imgproxy::Builder.new(styles(style).transform_keys(&:to_sym))
        builder.url_for("s3://#{Rails.application.config.s3_bucket.name}/#{ProjectStorage.daily_photos_prefix}/#{number}.JPG")
      else
        placeholder_url(style)
      end
    end
  end

  # Imgproxy URL for an arbitrary object key, e.g. a user/field photo stored
  # under <project>/user_photos/.... Unlike official daily photos there is no
  # number -> daily_photos mapping; the caller passes the full key recorded on
  # the locus, and the object is taken to exist (it's referenced in the record).
  def self.url_for_key(key, style)
    bucket = Rails.application.config.try(:s3_bucket)
    return placeholder_url(style) if bucket.nil?

    Rails.cache.fetch "photo_url_key_#{key}_#{style}" do
      builder = Imgproxy::Builder.new(styles(style).transform_keys(&:to_sym))
      builder.url_for("s3://#{bucket.name}/#{key}")
    end
  end

  def self.visible_loci(number)
    db = CouchDB.main_db

    Rails.cache.fetch "#{ProjectStorage.daily_photos_prefix}/visible_loci_#{number}" do
      db.view('opendig/photos', key: number, include_docs: false)['rows'].map do |row|
        row['value'][0]
      end
    end
  end
end
