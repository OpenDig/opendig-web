# A project is one archaeological dig, selected by subdomain (balua.opendig.org
# -> "balua"). Projects are not stored documents -- each project *is* a CouchDB
# database named "#{key}_#{env}" (e.g. balua_production, umayri_development), so
# the master list of projects is simply the set of matching databases.
class Project
  # The legacy single-tenant database key. Excluded from the project list until
  # its data is migrated into a real project database.
  LEGACY_KEYS = %w[opendig].freeze

  class << self
    # Project keys derived from the CouchDB databases for the current env,
    # e.g. ["balua", "umayri"]. Memoized per process+env since the set of
    # databases changes rarely (adding a project requires a restart to refresh).
    def all(env: CouchDB.env)
      @all ||= {}
      @all[env] ||= keys_for(env)
    end

    def exists?(key, env: CouchDB.env)
      return false if key.blank?

      all(env: env).include?(key.to_s)
    end

    def database_name(key, env: CouchDB.env)
      "#{key}_#{env}"
    end

    # Clear the memoized project list (e.g. after creating a new project db).
    def reset_cache!
      @all = {}
    end

    private

    def keys_for(env)
      suffix       = "_#{env}"
      users_db     = CouchDB.users_database_name(env)
      database_names(env)
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
      []
    end
  end
end
