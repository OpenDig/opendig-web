require 'rails_helper'

RSpec.describe AccountController, type: :controller do
  render_views # actually render the account template (catches view/helper errors)

  let(:users) { load_user_fixtures }

  it 'requires authentication' do
    get :show
    expect(response).to redirect_to(controller.root_path)
  end

  it 'shows the account page for a signed-in user' do
    session[:user_id] = users[:viewer].id
    get :show
    expect(response).to be_successful
  end

  describe 'POST create_pairing_code' do
    it 'generates a pairing code owned by the current user' do
      session[:user_id] = users[:viewer].id

      post :create_pairing_code, params: { device_name: 'iPad' }

      expect(response).to be_successful
      expect(assigns(:pairing_code).user_id).to eq(users[:viewer].id_as_string)
    ensure
      assigns(:pairing_code)&.destroy!
    end
  end

  describe 'GET pairing_status' do
    it 'reports pending for a live code and claimed once it is gone' do
      session[:user_id] = users[:viewer].id
      code = PairingCode.generate_for(users[:viewer])

      get :pairing_status, params: { code: code.code }
      expect(JSON.parse(response.body)['status']).to eq('pending')

      code.destroy! # simulate the device redeeming it
      get :pairing_status, params: { code: code.code }
      expect(JSON.parse(response.body)['status']).to eq('claimed')
    end
  end

  describe 'DELETE revoke_device' do
    it "revokes the current user's own device" do
      device, = Device.create_for(users[:viewer])
      session[:user_id] = users[:viewer].id

      delete :revoke_device, params: { id: device.device_id }

      expect(Device.find(device.device_id)).to be_nil
    end

    it "does not revoke another user's device" do
      device, = Device.create_for(users[:superuser])
      session[:user_id] = users[:viewer].id

      delete :revoke_device, params: { id: device.device_id }

      expect(Device.find(device.device_id)).not_to be_nil
    ensure
      device&.revoke!
    end
  end
end
