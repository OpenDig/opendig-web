require 'rails_helper'

RSpec.describe Device, type: :model do
  let(:users) { load_user_fixtures }
  let(:user) { users[:dig_director] }

  it 'creates a device and authenticates by its raw token' do
    device, token = described_class.create_for(user, device_name: 'Field iPad')
    expect(token).to be_present
    expect(device.token_digest).to eq(Digest::SHA256.hexdigest(token))

    found = described_class.authenticate(token)
    expect(found.device_id).to eq(device.device_id)
    expect(described_class.authenticate('wrong-token')).to be_nil
  ensure
    device&.revoke!
  end

  it "lists a user's devices and revokes them" do
    device, = described_class.create_for(user)
    expect(described_class.for_user(user.id_as_string).map(&:device_id)).to include(device.device_id)

    device.revoke!
    expect(described_class.for_user(user.id_as_string).map(&:device_id)).not_to include(device.device_id)
  end
end
