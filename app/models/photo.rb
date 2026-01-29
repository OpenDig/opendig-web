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
    Rails.cache.fetch "daily_photos/#{number}_exists" do
      bucket = Rails.application.config.s3_bucket
      bucket.object("daily_photos/#{number}.JPG").exists?
    end
  end

  def self.photo_url(number, style)
    Rails.cache.fetch "daily_photos/photo_url_#{number}_#{style}" do
      photo_style = styles(style)
      if photo_exists?(number)
        builder = Imgproxy::Builder.new(
          photo_style.transform_keys(&:to_sym)
        )
        builder.url_for("s3://#{Rails.application.config.s3_bucket.name}/daily_photos/#{number}.JPG")
      else
        height = photo_style[:height] || 1000
        width = photo_style[:width] || 1000
        "https://placehold.jp/#{height}x#{width}.jpg?text=No+Image"
      end
    end
  end

  def self.visible_loci(number)
    db = Rails.application.config.couchdb

    Rails.cache.fetch "daily_photos/visible_loci_#{number}" do
      db.view('opendig/photos', key: number, include_docs: false)['rows'].map do |row|
        row['value'][0]
      end
    end
  end
end
