require 'rails_helper'

RSpec.describe ProjectStorage do
  it 'scopes S3 key prefixes under the current project' do
    CouchDB.current_project = 'balua'

    expect(described_class.artifacts_prefix).to eq('balua/artifacts')
    expect(described_class.daily_photos_prefix).to eq('balua/daily_photos')
  end

  it 'raises when no project is resolved (never writes to an unscoped path)' do
    CouchDB.current_project = nil

    expect { described_class.storage_project }.to raise_error(/No current project/)
  end
end
