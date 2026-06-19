# Builds the configuration bundle handed to a paired mobile device. The device
# uses this to sync directly with CouchDB and render images via imgproxy itself,
# so the bundle carries the database credentials, the imgproxy info, the
# forms/lookups config, and the user's per-project role/scope.
#
# SECURITY: per the chosen "fast" path this includes the shared master CouchDB
# credentials (full access to all project databases) and the imgproxy signing
# secrets. Acceptable for a prototype only -- see the plan's security note.
class DeviceConfiguration
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      'user' => { 'email' => @user.email, 'name' => @user.name },
      'imgproxy' => imgproxy_config,
      'couchdb' => couchdb_config,
      'descriptions' => Rails.application.config.descriptions,
      'projects' => projects
    }
  end

  private

  # Projects this user can access: everything for a superuser, otherwise the
  # projects they hold a role in (that still exist).
  def project_keys
    @user.superuser? ? Project.all : (@user.roles.keys & Project.all)
  end

  def projects
    superuser = @user.superuser?
    project_keys.map do |key|
      {
        'key' => key,
        'name' => key.humanize,
        # A superuser is superuser on every project, even ones with no explicit
        # roles entry; otherwise report the user's stored role for that project.
        'role' => superuser ? 'superuser' : @user.role_for(key),
        'scopes' => @user.scopes_for(key),
        'database' => Project.database_name(key)
      }
    end
  end

  def imgproxy_config
    { 'url' => ENV.fetch('IMGPROXY_URL', nil), 'key' => ENV.fetch('IMGPROXY_KEY', nil), 'salt' => ENV.fetch('IMGPROXY_SALT', nil) }
  end

  def couchdb_config
    {
      'url' => ENV['COUCHDB_SYNC_URL'].presence || default_sync_url,
      'username' => ENV['COUCHDB_USER'] || couch_cfg['username'],
      'password' => ENV['COUCHDB_PASSWORD'] || couch_cfg['password']
    }
  end

  def couch_cfg
    @couch_cfg ||= CouchDB.config_for
  end

  def default_sync_url
    port = couch_cfg['port'] ? ":#{couch_cfg['port']}" : ''
    "#{couch_cfg['protocol']}://#{couch_cfg['host']}#{port}"
  end
end
