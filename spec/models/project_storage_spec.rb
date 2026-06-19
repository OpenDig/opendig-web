require 'rails_helper'

RSpec.describe ProjectStorage do
  it 'scopes S3 key prefixes under the current project' do
    CouchDB.current_project = 'balua'

    expect(described_class.artifacts_prefix).to eq('balua/artifacts')
    expect(described_class.daily_photos_prefix).to eq('balua/daily_photos')
    expect(described_class.user_photos_prefix).to eq('balua/user_photos')
  end

  it 'raises when no project is resolved (never writes to an unscoped path)' do
    CouchDB.current_project = nil

    expect { described_class.storage_project }.to raise_error(/No current project/)
  end

  describe '.user_photo_key' do
    before { CouchDB.current_project = 'balua' }

    it 'builds a self-describing, collision-resistant field-photo key' do
      key = described_class.user_photo_key(
        locus: 'L1023', user_id: 'u8f2a',
        taken_at: Time.utc(2026, 6, 19, 14, 33, 55), nonce: '3b9c'
      )

      expect(key).to eq('balua/user_photos/L1023-u8f2a-20260619T143355Z-3b9c.jpg')
    end

    it 'normalises unsafe characters and the extension' do
      key = described_class.user_photo_key(
        locus: 'Area 1/Sq 2', user_id: 'user@x.com',
        taken_at: Time.utc(2026, 1, 2, 3, 4, 5), ext: '.JPEG', nonce: 'ab12'
      )

      expect(key).to eq('balua/user_photos/Area_1_Sq_2-user_x_com-20260102T030405Z-ab12.jpeg')
    end

    it 'generates a unique nonce per call by default' do
      args = { locus: 'L1', user_id: 'u1', taken_at: Time.utc(2026, 1, 1) }

      expect(described_class.user_photo_key(**args)).not_to eq(described_class.user_photo_key(**args))
    end
  end
end
