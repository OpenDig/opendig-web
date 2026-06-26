require 'rails_helper'

RSpec.describe Registrar, type: :model do
  def find_with(state)
    described_class.new(['1', '1', '001', '1', '1', nil, 'Ceramic', 'remark', state, 'doc-id'])
  end

  describe '#stage' do
    it 'maps each stored state to its pipeline stage' do
      expect(find_with(nil).stage).to eq('incoming') # blank -> unregistered
      expect(find_with('').stage).to eq('incoming')
      expect(find_with('initial registration').stage).to eq('initial')
      expect(find_with('WIP').stage).to eq('pending')
      expect(find_with('registrarion complete').stage).to eq('completed')
      expect(find_with('discarded').stage).to eq('discarded')
    end

    it 'falls back to the first stage for an unrecognised state' do
      expect(find_with('something unexpected').stage).to eq('incoming')
    end
  end
end
