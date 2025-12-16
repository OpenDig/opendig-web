require 'couchrest'

class HTTPClient
  alias original_initialize initialize

  def initialize(*args, &block)
    original_initialize(*args, &block)
    # Force use of the default system CA certs (instead of the 6 year old bundled ones)
    @session_manager&.ssl_config&.set_default_paths
  end
end

couchdb_config = YAML.load_file("#{Rails.root}/config/couchdb.yml")[Rails.env]
protocol = couchdb_config["protocol"]
host     = couchdb_config["host"]
port     = couchdb_config["port"] || nil
username = couchdb_config["username"]
password = couchdb_config["password"]
db_name  = couchdb_config["db_name"] || nil
prefix   = couchdb_config["prefix"] || nil
suffix   = couchdb_config["suffix"] || nil

database = db_name ? db_name : "#{prefix}_#{suffix}"
host = ENV['COUCHDB_HOST'] || couchdb_config["host"]
url = "#{protocol}://#{username}:#{password}@#{host}:#{port}/#{database}"
Rails.application.config.couchdb = CouchRest.database!(url)

def get_config
  doc_id = 'opendig_config'
  begin
    doc = Rails.application.config.couchdb.get(doc_id) rescue nil

    if doc.nil?
      Rails.logger.info "No config doc found (#{doc_id}), creating default"
      default = {'_id' => doc_id, 'version' => 0}
      Rails.application.config.couchdb.save_doc(default)
      default
    else
      doc
    end
  rescue => e
    Rails.logger.error "Error fetching config doc: #{e.class}: #{e.message}"
    default = {'_id' => doc_id, 'version' => 0}
    Rails.application.config.couchdb.save_doc(default) rescue nil
    default
  end
end

design = YAML.load_file("#{Rails.root}/config/views.yaml")
config = get_config
config_version = (config[:version] || 0).to_i
design_version = (design[:version] || 0).to_i

if config_version != design_version
  Rails.logger.info "Design docs out of date, updating"
  if design_docs = Rails.application.config.couchdb.get('_design/opendig')
    design_docs["views"] = design[:design][:views]
    design_docs.save
  else
    Rails.application.config.couchdb.save_doc(design[:design])
  end

  # bump and persist the config version so next boot knows it's up to date
  cfg = Rails.application.config.couchdb.get('opendig_config') rescue nil
  if cfg
    cfg['version'] = design_version
    Rails.application.config.couchdb.save_doc(cfg)
  end
else
  Rails.logger.info "Design docs up to date"
end
