require 'rails_helper'

RSpec.describe Api::V1::ConfigController, type: :controller do
  let(:users) { load_user_fixtures }

  before { allow(Project).to receive(:all).and_return(['opendig']) }

  it 'returns the config bundle for a valid bearer token' do
    device, token = Device.create_for(users[:dig_director])
    request.headers['Authorization'] = "Bearer #{token}"

    get :show

    body = JSON.parse(response.body)
    expect(response).to have_http_status(:ok)
    expect(body['projects'].map { |p| p['key'] }).to include('opendig')
  ensure
    device&.revoke!
  end

  it 'rejects a missing token' do
    get :show
    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects a garbage token' do
    request.headers['Authorization'] = 'Bearer not-a-real-token'
    get :show
    expect(response).to have_http_status(:unauthorized)
  end
end
