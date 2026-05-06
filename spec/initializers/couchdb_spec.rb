require 'rails_helper'

RSpec.describe CouchDB do
  describe "#initialize" do
    it "loads configuration from the specified file and environment" do
      couchdb = CouchDB.new(config_path: 'config/couchdb.yml', env: 'test')
      expect(couchdb.config).to be_a(Hash)
      expect(couchdb.config["host"]).to eq("db")
    end

    it "allows overriding config values with environment variables" do
      ENV['COUCHDB_HOST'] = 'env_host'
      couchdb = CouchDB.new(config_path: 'config/couchdb.yml', env: 'test', dry_run: true)
      expect(couchdb.config["host"]).to eq("env_host")
      ENV.delete('COUCHDB_HOST')
    end

    it "constructs the database name correctly based on prefix and suffix" do
      couchdb = CouchDB.new(config_path: 'config/couchdb.yml', env: 'test')
      expected_db_name = "opendig_test"
      expect(couchdb.client.name).to eq(expected_db_name)
    end
  end
end