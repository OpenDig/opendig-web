class Photo
  def self.styles(style)
    {
      medium: {
        height: 1000,
        width: 1000
      },
      # Crisp on-the-fly preview for photo grids/cards. Larger than `thumb` so it
      # stays sharp on hi-DPI screens; `fit` keeps the whole frame (CSS crops it).
      preview: {
        height: 600,
        width: 600,
        resizing_type: 'fit',
        quality: 82
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

  # The stored object key for a daily-photo number. Daily photos are
  # <number>.<ext>, but the extension's case varies across data migrations
  # (.JPG vs .jpg) and S3 keys are case-sensitive, so resolve the actual object
  # by prefix instead of assuming one extension.
  def self.object_key_for(number)
    bucket = Rails.application.config.try(:s3_bucket)
    return nil if bucket.nil?

    Rails.cache.fetch "#{ProjectStorage.daily_photos_prefix}/#{number}_key" do
      bucket.objects(prefix: "#{ProjectStorage.daily_photos_prefix}/#{number}.").first&.key
    end
  rescue StandardError => e
    Rails.logger.warn("Photo.object_key_for failed for #{number}: #{e.class}: #{e.message}")
    nil
  end

  def self.photo_exists?(number)
    object_key_for(number).present?
  end

  def self.photo_url(number, style)
    Rails.cache.fetch "#{ProjectStorage.daily_photos_prefix}/photo_url_#{number}_#{style}" do
      key = object_key_for(number)
      if key
        builder = Imgproxy::Builder.new(styles(style).transform_keys(&:to_sym))
        builder.url_for("s3://#{Rails.application.config.s3_bucket.name}/#{key}")
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
