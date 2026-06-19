require 'rails_helper'

RSpec.describe Project, type: :model do
  before { described_class.reset_cache! }
  after  { described_class.reset_cache! }

  describe '.all' do
    it 'lists project keys from matching databases, excluding system and users dbs' do
      allow(CouchDB).to receive(:users_database_name).with('production').and_return('opendig_users_production')
      allow(CouchDB).to receive(:server).and_return(
        instance_double(CouchRest::Server, databases: %w[
                          balua_production umayri_production opendig_users_production
                          _users _replicator balua_development opendig_production
                        ])
      )

      # _development dbs, system dbs, the users db, and the legacy "opendig" key are excluded.
      expect(described_class.all(env: 'production')).to eq(%w[balua umayri])
    end

    it 'returns [] when the database list cannot be fetched' do
      allow(CouchDB).to receive(:users_database_name).and_return('opendig_users_production')
      allow(CouchDB).to receive(:server).and_raise(StandardError)
      expect(described_class.all(env: 'production')).to eq([])
    end

    it 're-polls for new databases after the TTL, with no restart' do
      server = instance_double(CouchRest::Server)
      allow(CouchDB).to receive_messages(users_database_name: 'opendig_users_production', server: server)
      allow(described_class).to receive(:monotonic_now).and_return(0)

      allow(server).to receive(:databases).and_return(%w[balua_production])
      expect(described_class.all(env: 'production')).to eq(%w[balua])

      # A new project db appears; within the TTL the cached list is still served.
      allow(server).to receive(:databases).and_return(%w[balua_production umayri_production])
      expect(described_class.all(env: 'production')).to eq(%w[balua])

      # Once the TTL passes, the next call re-polls and picks the new one up.
      allow(described_class).to receive(:monotonic_now).and_return(Project::CACHE_TTL_SECONDS + 1)
      expect(described_class.all(env: 'production')).to eq(%w[balua umayri])
    end

    it 'keeps serving the last known list when a re-poll fails' do
      server = instance_double(CouchRest::Server)
      allow(CouchDB).to receive_messages(users_database_name: 'opendig_users_production', server: server)
      allow(described_class).to receive(:monotonic_now).and_return(0)
      allow(server).to receive(:databases).and_return(%w[balua_production])
      expect(described_class.all(env: 'production')).to eq(%w[balua])

      allow(described_class).to receive(:monotonic_now).and_return(Project::CACHE_TTL_SECONDS + 1)
      allow(server).to receive(:databases).and_raise(StandardError)
      expect(described_class.all(env: 'production')).to eq(%w[balua]) # not []
    end
  end

  describe '.exists?' do
    it 'is true for a known project and false otherwise' do
      allow(described_class).to receive(:all).and_return(%w[balua umayri])
      expect(described_class.exists?('balua')).to be(true)
      expect(described_class.exists?('nope')).to be(false)
      expect(described_class.exists?(nil)).to be(false)
    end
  end

  describe '.database_name' do
    it 'joins the key and the environment' do
      expect(described_class.database_name('balua', env: 'production')).to eq('balua_production')
    end
  end
end
