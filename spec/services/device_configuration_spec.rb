require 'rails_helper'

RSpec.describe DeviceConfiguration do
  let(:users) { load_user_fixtures }

  before { allow(Project).to receive(:all).and_return(%w[opendig balua]) }

  it 'lists the projects the user has a role in, with role and scope' do
    config = described_class.new(users[:area_supervisor]).as_json

    project = config['projects'].find { |p| p['key'] == 'opendig' }
    expect(project['role']).to eq('area_supervisor')
    expect(project['scopes']).to eq(['1'])
    expect(project['database']).to eq('opendig_test')
    expect(config['projects'].map { |p| p['key'] }).not_to include('balua') # not a member
  end

  it 'gives a superuser every project, as superuser' do
    config = described_class.new(users[:superuser]).as_json
    expect(config['projects'].map { |p| p['key'] }).to match_array(%w[opendig balua])
    expect(config['projects'].map { |p| p['role'] }.uniq).to eq(['superuser'])
  end

  it 'includes imgproxy info, couchdb credentials and the descriptions config' do
    config = described_class.new(users[:dig_director]).as_json

    expect(config['imgproxy']).to include('url', 'key', 'salt')
    expect(config['couchdb']).to include('url', 'username', 'password')
    expect(config['descriptions']).to be_present
    expect(config['user']).to include('email', 'name')
  end
end
