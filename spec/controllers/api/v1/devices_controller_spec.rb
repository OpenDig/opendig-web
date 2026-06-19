require 'rails_helper'

RSpec.describe Api::V1::DevicesController, type: :controller do
  let(:users) { load_user_fixtures }

  before { allow(Project).to receive(:all).and_return(['opendig']) }

  describe 'POST pair' do
    it 'redeems a valid code and returns a token + config bundle' do
      code = PairingCode.generate_for(users[:dig_director], device_name: 'iPad')

      post :pair, params: { code: code.code, device_name: 'iPad' }

      body = JSON.parse(response.body)
      expect(response).to have_http_status(:created)
      expect(body['token']).to be_present
      expect(body['config']['projects'].map { |p| p['key'] }).to include('opendig')
      expect(body['config']['couchdb']).to include('username', 'password', 'url')
    ensure
      Device.authenticate(JSON.parse(response.body)['token'])&.revoke!
    end

    it 'rejects an invalid or expired code' do
      post :pair, params: { code: 'BADCODE1' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'DELETE destroy' do
    it 'revokes the authenticated device' do
      _device, token = Device.create_for(users[:dig_director])
      request.headers['Authorization'] = "Bearer #{token}"

      delete :destroy

      expect(response).to have_http_status(:no_content)
      expect(Device.authenticate(token)).to be_nil
    end

    it 'is unauthorized without a token' do
      delete :destroy
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
