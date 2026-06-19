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

  def self.photo_exists?(number)
    Rails.cache.fetch "#{ProjectStorage.daily_photos_prefix}/#{number}_exists" do
      bucket = Rails.application.config.s3_bucket
      bucket.object("#{ProjectStorage.daily_photos_prefix}/#{number}.JPG").exists?
    end
  end

  def self.photo_url(number, style)
    Rails.cache.fetch "#{ProjectStorage.daily_photos_prefix}/photo_url_#{number}_#{style}" do
      photo_style = styles(style)
      if photo_exists?(number)
        builder = Imgproxy::Builder.new(
          photo_style.transform_keys(&:to_sym)
        )
        builder.url_for("s3://#{Rails.application.config.s3_bucket.name}/#{ProjectStorage.daily_photos_prefix}/#{number}.JPG")
      else
        height = photo_style[:height] || 1000
        width = photo_style[:width] || 1000
        "https://placehold.jp/#{height}x#{width}.jpg?text=No+Image"
      end
    end
  end

  # Imgproxy URL for an arbitrary object key, e.g. a user/field photo stored
  # under <project>/user_photos/.... Unlike official daily photos there is no
  # number -> daily_photos mapping; the caller passes the full key recorded on
  # the locus, and the object is taken to exist (it's referenced in the record).
  def self.url_for_key(key, style)
    Rails.cache.fetch "photo_url_key_#{key}_#{style}" do
      photo_style = styles(style)
      builder = Imgproxy::Builder.new(photo_style.transform_keys(&:to_sym))
      builder.url_for("s3://#{Rails.application.config.s3_bucket.name}/#{key}")
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
