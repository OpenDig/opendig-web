# Builds the configuration bundle handed to a paired mobile device. The device
# uses this to sync directly with CouchDB, upload/fetch artifacts and daily
# photos straight to/from S3, and render images via imgproxy itself, so the
# bundle carries the database credentials, the S3 bucket + credentials, the
# imgproxy info, the forms/lookups config, and the user's per-project role/scope.
#
# SECURITY: per the chosen "fast" path this includes the shared master CouchDB
# credentials (full access to all project databases), the S3 access keys, and the
# imgproxy signing secrets. Acceptable for a prototype only -- see the plan's
# security note (per-user scoped creds are the recommended follow-up).
class DeviceConfiguration
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      'user' => { 'email' => @user.email, 'name' => @user.name },
      'imgproxy' => imgproxy_config,
      'couchdb' => couchdb_config,
      's3' => s3_config,
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
        'database' => Project.database_name(key),
        'storage' => storage_prefixes(key)
      }
    end
  end

  # Where this project's files live in the shared bucket. Resolved through
  # ProjectStorage so the device keys objects exactly as the server does.
  def storage_prefixes(key)
    CouchDB.with_project(key) do
      {
        'artifacts_prefix' => ProjectStorage.artifacts_prefix,
        'daily_photos_prefix' => ProjectStorage.daily_photos_prefix
      }
    end
  end

  def imgproxy_config
    { 'url' => ENV.fetch('IMGPROXY_URL', nil), 'key' => ENV.fetch('IMGPROXY_KEY', nil), 'salt' => ENV.fetch('IMGPROXY_SALT', nil) }
  end

  # The shared S3 bucket the device uploads to / fetches from directly. endpoint
  # is nil for real AWS and set (force_path_style) for a custom endpoint like the
  # dev minio. Objects are written public-read, matching server-side uploads.
  def s3_config
    {
      'bucket' => bucket_name,
      'region' => ENV.fetch('AWS_REGION', 'us-east-1'),
      'endpoint' => ENV['S3_URL'].presence,
      'force_path_style' => ENV['S3_URL'].present?,
      'access_key_id' => ENV.fetch('AWS_ACCESS_KEY_ID', nil),
      'secret_access_key' => ENV.fetch('AWS_SECRET_ACCESS_KEY', nil),
      'acl' => 'public-read'
    }
  end

  def bucket_name
    Rails.application.config.try(:s3_bucket)&.name || ENV.fetch('S3_BUCKET', 'opendig')
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
