require 'couchrest'

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
url = "#{protocol}://#{username}:#{password}@#{host}:#{port}/#{database}"
Rails.application.config.couchdb = CouchRest.database!(url)

def get_config
  begin
    # first, retrieve the existing config to see if the version has changed
    Rails.application.config.couchdb.view('opendig/config')["rows"].first["value"]
  rescue #CouchRest::NotFound
    puts "No config found, defaulting to zero"
    return {'version': 0}
  end
end

design = YAML.load_file("#{Rails.root}/config/views.yaml")
config = get_config
puts "Config version: #{config[:version]}, design version: #{design[:version]}"
if config[:version] != design[:version]
  Rails.logger.info "Design docs out of date, updating"
  if design_docs = Rails.application.config.couchdb.get('_design/opendig')
    design_docs["views"] = design[:design][:views]
    design_docs.save
  else
    Rails.application.config.couchdb.save_doc(design[:design])
  end
else
  Rails.logger.info "Design docs up to date"
end
