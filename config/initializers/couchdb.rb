require 'couchrest'

class HTTPClient
  alias original_initialize initialize

  def initialize(*args, &block)
    original_initialize(*args, &block)
    # Force use of the default system CA certs (instead of the 6 year old bundled ones)
    @session_manager&.ssl_config&.set_default_paths
  end
end

class CouchDB
  CONFIG_PATH = 'config/couchdb.yml'.freeze

  # Singleton pattern (these are class methods)
  class << self
    # The main database is now per-project: each project (selected by subdomain)
    # lives in its own CouchDB database named "#{project}_#{env}". Connections are
    # cached per (env, project). The project defaults to the request-scoped
    # `current_project` so model code can keep calling `CouchDB.main_db` with no args.
    def main_db(project = current_project)
      raise NoProjectError, 'No current project resolved for CouchDB.main_db' if project.blank?

      @main_dbs ||= {}
      @main_dbs[[env, project.to_s]] ||= CouchDB.new(env: env, db_name: Project.database_name(project, env: env))
    end

    # The auth/users database is shared across all projects.
    def auth_db
      @auth_db = CouchDB.new(env: env, design_docs_path: 'config/auth_views.yaml', label: 'users', config_doc_id: 'authdb_config', design_doc_id: '_design/authdb') unless @auth_db&.env == env
      @auth_db
    end

    # main_db is no longer enumerable without a project, so `dbs` covers only the
    # shared databases. Callers that need a project db should use `main_db(project)`.
    def dbs = [auth_db]

    # Request-scoped current project key. Set by ApplicationController#resolve_project
    # for requests; set explicitly (or via `with_project`) for rake/lib/specs.
    def current_project = Thread.current[:couchdb_project]

    def current_project=(project)
      Thread.current[:couchdb_project] = project&.to_s
    end

    # Run a block with a given current project, restoring the previous one after.
    def with_project(project)
      previous = current_project
      self.current_project = project
      yield
    ensure
      self.current_project = previous
    end

    # A server-level connection (for _all_dbs etc.), built from the same config
    # and ENV overrides that an instance connection uses.
    def server
      cfg      = config_for(env)
      protocol = cfg['protocol']
      host     = ENV['COUCHDB_HOST'] || cfg['host']
      port     = cfg['port']
      username = ENV['COUCHDB_USER'] || cfg['username']
      password = ENV['COUCHDB_PASSWORD'] || cfg['password']
      authority = "#{username}:#{password}@#{host}#{port ? ":#{port}" : ''}"
      CouchRest.new("#{protocol}://#{authority}")
    end

    # Name of the shared users database, computed without opening a connection.
    def users_database_name(env = self.env)
      cfg    = config_for(env)
      prefix = cfg['prefix'].is_a?(Hash) ? cfg.dig('prefix', 'users') : cfg['prefix']
      suffix = cfg['suffix'].is_a?(Hash) ? cfg.dig('suffix', 'users') : cfg['suffix']
      "#{prefix}_#{suffix}"
    end

    def config_for(env = self.env)
      YAML.load_file("#{Rails.root}/#{CONFIG_PATH}")[env].with_indifferent_access
    end

    def set_env!(env = Rails.env)
      @env = env
      @main_dbs = {}
      @auth_db = nil
      @env
    end

    def env = @env || Rails.env
  end

  class NoProjectError < StandardError; end

  attr_reader :client, :config, :label, :env

  def initialize(delete_db: false, dry_run: false, **params)
    default_params = {
      design_docs_path: 'config/views.yaml',
      config_path: 'config/couchdb.yml',
      label: 'main',
      config_doc_id: 'opendig_config',
      design_doc_id: '_design/opendig',
      env: self.class.env
    }
    params = default_params.merge(params).with_indifferent_access
    @config = YAML.load_file("#{Rails.root}/#{params[:config_path]}")[params[:env]].with_indifferent_access
    @config_doc_id = params[:config_doc_id]
    @design_doc_id = params[:design_doc_id]
    @label = params[:label]
    @env = params[:env]
    protocol = @config["protocol"]
    @config["host"]     = ENV['COUCHDB_HOST'] || @config["host"]
    @config["port"]     = @config["port"] || nil
    @config["username"] = ENV['COUCHDB_USER'] || @config["username"]
    @config["password"] = ENV['COUCHDB_PASSWORD'] || @config["password"]
    @config["params"]   = params

    # Explanation of db naming:
    # 1. If prefix, suffix, or db_name are explicitly provided in config, use them directly.
    # 2. If db_name is not provided, construct it from prefix and suffix.
    # 3. Prefix, suffix, and db_name can each be either a string or a hash keyed by label to allow multiple db configs in the same file.
    #
    # For example, with the following config: (taken from existing config/couchdb.yml)
    # default:
    #   prefix:
    #     main: opendig
    #     users: opendig_users
    # development:
    #   <<: *default
    #   suffix: development
    # production:
    #   <<: *default
    #   suffix: production
    #
    # You can have two separate databases, for instance opendig_development and opendig_auth_development, by using the 'main' and 'auth' labels when initializing CouchDB instances:
    # `Rails.application.config.main_db = CouchDB.new(label: 'main')`
    # `Rails.application.config.auth_db = CouchDB.new(label: 'auth')`
    # Whereas in production these will automatically connect to opendig_production and opendig_auth_production respectively.
    prefix   = (@config["prefix"].is_a?(Hash) ? @config.dig("prefix", @label) : @config["prefix"]) || nil
    suffix   = (@config["suffix"].is_a?(Hash) ? @config.dig("suffix", @label) : @config["suffix"]) || nil
    # An explicit db_name passed at construction (used by the per-project main_db)
    # takes precedence over the prefix/suffix convention.
    database = params[:db_name] ||
               (@config["db_name"].is_a?(Hash) ? @config.dig("db_name", @label) : @config["db_name"]) ||
               "#{prefix}_#{suffix}"
    return if dry_run # skip actual DB connection if just testing config loading

    url = "#{protocol}://#{@config['username']}:#{@config['password']}@#{@config['host']}:#{@config['port']}/#{database}"
    @client = CouchRest.database!(url)
    clear_db! if delete_db

    update_design_docs!(@config[:params][:design_docs_path])
  end

  def clear_db!
    @client.delete! rescue nil
    @client = CouchRest.database!(@client.uri)
    update_design_docs!(@config[:params][:design_docs_path])
    self
  end

  def get_config
    doc = @client.get(@config_doc_id) rescue nil

    if doc.nil?
      Rails.logger.info "No config doc found for #{@label} db (#{@config_doc_id}), creating default"
      default = {'_id' => @config_doc_id, 'version' => 0}
      @client.save_doc(default)
      default
    else
      doc
    end
  rescue => e
    Rails.logger.error "Error fetching config doc for #{@label} db : #{e.class}: #{e.message}"
    default = {'_id' => @config_doc_id, 'version' => 0}
    @client.save_doc(default) rescue nil
    default
  end

  def update_design_docs!(design_docs_path = "config/views.yaml")
    design = YAML.load_file("#{Rails.root}/#{design_docs_path}")
    config = get_config
    config_version = (config[:version] || 0).to_i
    design_version = (design[:version] || 0).to_i

    if config_version != design_version
      Rails.logger.info "Design docs out of date for #{@label} db, updating"
      if design_docs = @client.get(@design_doc_id)
        design_docs["views"] = design[:design][:views]
        design_docs.save
      else
        @client.save_doc(design[:design])
      end

      # bump and persist the config version so next boot knows it's up to date
      cfg = @client.get(@config_doc_id) rescue nil
      if cfg
        cfg['version'] = design_version
        @client.save_doc(cfg)
      end
    else
      Rails.logger.info "Design docs up to date for #{@label} db"
    end
  end

  def method_missing(method_name, *args, **kwargs, &block)
    if client.respond_to?(method_name)
      client.send(method_name, *args, **kwargs, &block)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    client.respond_to?(method_name) || super
  end
end
