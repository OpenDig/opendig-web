require 'rails_helper'

RSpec.describe CouchDB do
  describe "#initialize" do
    it "loads configuration from the specified file and environment" do
      couchdb = described_class.new(config_path: 'config/couchdb.yml', env: 'test', dry_run: true)
      expect(couchdb.config).to be_a(Hash)
      # Host comes from the config file, overridable by COUCHDB_HOST (e.g. in CI).
      expect(couchdb.config["host"]).to eq(ENV['COUCHDB_HOST'] || 'db')
    end

    it "allows overriding config values with environment variables" do
      original = ENV.fetch('COUCHDB_HOST', nil)
      ENV['COUCHDB_HOST'] = 'env_host'
      couchdb = described_class.new(config_path: 'config/couchdb.yml', env: 'test', dry_run: true)
      expect(couchdb.config["host"]).to eq('env_host')
    ensure
      original.nil? ? ENV.delete('COUCHDB_HOST') : (ENV['COUCHDB_HOST'] = original)
    end

    it "constructs the database name correctly based on prefix and suffix" do
      couchdb = described_class.new(config_path: 'config/couchdb.yml', env: 'test')
      expect(couchdb.client.name).to eq("opendig_test")
    end
  end
end
