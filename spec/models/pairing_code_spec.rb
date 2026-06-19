require 'rails_helper'

RSpec.describe PairingCode, type: :model do
  let(:users) { load_user_fixtures }
  let(:user) { users[:dig_director] }

  it 'generates a single-use code that redeems exactly once' do
    code = described_class.generate_for(user, device_name: 'iPad')
    expect(code.code).to be_present

    redeemed = described_class.redeem(code.code)
    expect(redeemed.user_id).to eq(user.id_as_string)
    expect(described_class.redeem(code.code)).to be_nil # single-use: already consumed
  end

  it 'returns nil for an unknown code' do
    expect(described_class.redeem('NOPECODE')).to be_nil
  end

  it 'does not redeem an expired code' do
    code = described_class.generate_for(user)
    travel_to(20.minutes.from_now) do
      expect(described_class.redeem(code.code)).to be_nil
    end
  ensure
    code&.destroy!
  end
end
