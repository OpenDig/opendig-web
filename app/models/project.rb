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
