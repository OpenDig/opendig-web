require 'rails_helper'

RSpec.describe DeviceConfiguration do
  let(:users) { load_user_fixtures }
  let(:wasabi_env) do
    { 'S3_BUCKET' => 'opendig', 'S3_URL' => 'https://s3.eu-central-1.wasabisys.com',
      'AWS_REGION' => 'eu-central-1', 'AWS_ACCESS_KEY_ID' => 'AKIA', 'AWS_SECRET_ACCESS_KEY' => 'secret' }
  end

  before { allow(Project).to receive(:all).and_return(%w[opendig balua]) }

  it 'lists the projects the user has a role in, with role, scope and storage prefixes' do
    config = described_class.new(users[:area_supervisor]).as_json

    project = config['projects'].find { |p| p['key'] == 'opendig' }
    expect(project['role']).to eq('area_supervisor')
    expect(project['scopes']).to eq(['1'])
    expect(project['database']).to eq('opendig_test')
    expect(project['storage']).to eq(
      'artifacts_prefix' => 'opendig/artifacts', 'daily_photos_prefix' => 'opendig/daily_photos',
      'user_photos_prefix' => 'opendig/user_photos'
    )
    expect(config['projects'].map { |p| p['key'] }).not_to include('balua') # not a member
  end

  it 'includes the Wasabi endpoint, region, credentials and a path-style base URL' do
    config = with_env(wasabi_env) { described_class.new(users[:dig_director]).as_json }

    expect(config['s3']).to include(
      'bucket' => 'opendig', 'region' => 'eu-central-1',
      'endpoint' => 'https://s3.eu-central-1.wasabisys.com', 'force_path_style' => true,
      'public_url_base' => 'https://s3.eu-central-1.wasabisys.com/opendig',
      'access_key_id' => 'AKIA', 'secret_access_key' => 'secret', 'acl' => 'public-read'
    )
  end

  it 'falls back to an AWS virtual-hosted base URL only when no endpoint is set' do
    config = with_env('S3_BUCKET' => 'opendig', 'S3_URL' => nil, 'AWS_REGION' => 'us-east-1') do
      described_class.new(users[:dig_director]).as_json
    end

    expect(config['s3']['endpoint']).to be_nil
    expect(config['s3']['public_url_base']).to eq('https://opendig.s3.us-east-1.amazonaws.com')
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
