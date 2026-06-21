# A project is one archaeological dig, selected by subdomain (balua.opendig.org
# -> "balua"). Projects are not stored documents -- each project *is* a CouchDB
# database named "#{key}_#{env}" (e.g. balua_production, umayri_development), so
# the master list of projects is simply the set of matching databases.
class Project
  # The legacy single-tenant database key. Excluded from the project list until
  # its data is migrated into a real project database.
  LEGACY_KEYS = %w[opendig].freeze

  # How long a discovered database list is trusted before re-polling CouchDB.
  # Short enough to pick up a newly-created project without a restart, long
  # enough that _all_dbs load stays negligible. Override with PROJECT_DB_REFRESH
  # (seconds; 0 = always re-poll).
  CACHE_TTL_SECONDS = ENV.fetch('PROJECT_DB_REFRESH', 60).to_i

  class << self
    # Project keys for the current env, e.g. ["balua", "umayri"], derived from the
    # CouchDB databases. Cached with a short TTL and re-polled on expiry, so a
    # newly created project database is picked up automatically -- no restart.
    def all(env: CouchDB.env)
      @cache ||= {}
      entry = @cache[env]
      return entry[:keys] if entry && entry[:expires_at] > monotonic_now

      fresh = keys_for(env)
      if fresh
        @cache[env] = { keys: fresh, expires_at: monotonic_now + CACHE_TTL_SECONDS }
        fresh
      else
        # A failed poll keeps serving the last known list rather than dropping
        # every project; only an empty initial cache yields [].
        entry ? entry[:keys] : []
      end
    end

    def exists?(key, env: CouchDB.env)
      return false if key.blank?

      all(env: env).include?(key.to_s)
    end

    def database_name(key, env: CouchDB.env)
      "#{key}_#{env}"
    end

    # Drop the cached list so the next call re-polls immediately (e.g. right
    # after creating a project database).
    def reset_cache!
      @cache = {}
    end

    # --- project metadata (cover photo + description) ----------------------
    #
    # A project has no document of its own (it *is* a database), so optional
    # presentation metadata lives in a single doc, `_id: "project"`, inside the
    # project's CouchDB database.
    META_DOC_ID = 'project'.freeze

    def metadata(key, env: CouchDB.env)
      return {} if key.blank? || !exists?(key, env: env)

      CouchDB.main_db(key).get(META_DOC_ID)
    rescue StandardError
      {}
    end

    def display_name(key, env: CouchDB.env)
      metadata(key, env: env)['name'].presence || key.to_s.humanize
    end

    def description(key, env: CouchDB.env)
      metadata(key, env: env)['description'].presence
    end

    def cover_photo_key(key, env: CouchDB.env)
      metadata(key, env: env)['cover_photo'].presence
    end

    # imgproxy URL for the project's cover photo, or nil when none is set.
    def cover_photo_url(key, style = :medium, env: CouchDB.env)
      cover = cover_photo_key(key, env: env)
      return nil if cover.blank?

      photo_style = Photo.styles(style)
      Imgproxy::Builder.new(photo_style.transform_keys(&:to_sym))
                       .url_for("s3://#{bucket_name}/#{cover}")
    rescue StandardError
      nil
    end

    # Provision a brand-new project: create its CouchDB database (which also
    # pushes the design docs) and seed the metadata doc. Returns the key.
    def create!(key, name: nil, description: nil, env: CouchDB.env)
      key = normalize_key(key)
      raise ArgumentError, 'A project key is required' if key.blank?
      raise ArgumentError, "Project '#{key}' already exists" if exists?(key, env: env)

      # Instantiating a CouchDB connection with an explicit db_name creates the
      # database if missing and installs the design docs.
      db = CouchDB.new(env: env, db_name: database_name(key, env: env))
      db.save_doc(
        '_id' => META_DOC_ID,
        'type' => 'project',
        'name' => name.presence || key.humanize,
        'description' => description
      )
      reset_cache!
      key
    end

    # Update presentation metadata for an existing project.
    def update_metadata(key, name: nil, description: nil, cover_photo: nil, env: CouchDB.env)
      db = CouchDB.main_db(key)
      doc = (db.get(META_DOC_ID) rescue nil) || { '_id' => META_DOC_ID, 'type' => 'project' }
      doc['name'] = name unless name.nil?
      doc['description'] = description unless description.nil?
      doc['cover_photo'] = cover_photo unless cover_photo.nil?
      db.save_doc(doc)
      doc
    end

    # Object key for a project's cover photo within the shared bucket.
    def cover_photo_object_key(key, filename)
      ext = File.extname(filename.to_s).downcase
      "#{normalize_key(key)}/cover/cover#{ext.empty? ? '.jpg' : ext}"
    end

    def bucket_name
      Rails.application.config.try(:s3_bucket)&.name || ENV.fetch('S3_BUCKET', 'opendig')
    end

    def normalize_key(key)
      key.to_s.strip.downcase.gsub(/[^a-z0-9_]+/, '_').gsub(/\A_+|_+\z/, '')
    end

    private

    def monotonic_now
      Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # Project keys for the env, or nil if the database list could not be fetched
    # (so the caller can fall back to the last known list).
    def keys_for(env)
      names = database_names(env)
      return nil if names.nil?

      suffix   = "_#{env}"
      users_db = CouchDB.users_database_name(env)
      names
        .reject { |name| name.start_with?('_') } # CouchDB system databases
        .select { |name| name.end_with?(suffix) }
        .map    { |name| name.delete_suffix(suffix) }
        .reject { |key| key == users_db.delete_suffix(suffix) } # shared auth db
        .reject { |key| LEGACY_KEYS.include?(key) }
        .sort
    end

    def database_names(_env)
      CouchDB.server.databases
    rescue StandardError => e
      Rails.logger.error "Failed to list CouchDB databases for Project.all: #{e.class}: #{e.message}"
      nil
    end
  end
end
