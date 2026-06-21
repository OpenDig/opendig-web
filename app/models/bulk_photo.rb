# Convention-named photos sitting in the project's bucket (see PhotoName),
# matched to loci by their filename. A photo can be linked to many loci; until
# it's linked to at least one it is "pending" for its square.
class BulkPhoto
  Entry = Struct.new(:key, :name, :linked_to, keyword_init: true) do
    def filename = File.basename(key)
    def thumb_url = Photo.url_for_key(key, :thumb)
    def preview_url = Photo.url_for_key(key, :preview)
    def full_url = Photo.url_for_key(key, :original)
    def pending? = linked_to.empty?
  end

  class << self
    # Every convention-named photo in the bucket, with the loci it's already
    # linked to. Legacy numbered photos ({number}.JPG) live in the same prefix
    # but don't match the convention, so they're excluded here (they're handled
    # by `rake photos:backfill_keys`, not the tagging UI).
    def all
      linked = linked_keys
      bucket_keys.filter_map do |key|
        name = PhotoName.parse(File.basename(key))
        next unless name.valid?

        Entry.new(key: key, name: name, linked_to: linked[key] || [])
      end
    end

    # Photos whose filename area+square match the given square.
    def for_square(area, square)
      all.select do |e|
        norm(e.name.area) == norm(area) && norm(e.name.square) == norm(square)
      end
    end

    # Square photos not yet linked to any locus.
    def pending_for_square(area, square)
      for_square(area, square).select(&:pending?)
    end

    private

    def bucket_keys
      bucket = Rails.application.config.try(:s3_bucket)
      return [] if bucket.nil?

      bucket.objects(prefix: "#{ProjectStorage.daily_photos_prefix}/")
            .map(&:key)
            .reject { |k| k.end_with?('/') }
    rescue StandardError => e
      Rails.logger.error "Bulk photo list failed: #{e.class}: #{e.message}"
      []
    end

    # s3 key => [locus codes it's linked to].
    def linked_keys
      CouchDB.main_db.view('opendig/photo_keys')['rows']
             .each_with_object(Hash.new { |h, k| h[k] = [] }) do |row, h|
        h[row['key']] << row['value'][0]
      end
    rescue StandardError
      {}
    end

    def norm(value)
      s = value.to_s.strip
      s.match?(/\A\d+\z/) ? s.to_i.to_s : s.downcase
    end
  end
end
