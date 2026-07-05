require 'rails_helper'

RSpec.describe LocusMerge do
  describe '.merge' do
    it 'preserves find fields the form did not submit (photos/cover/state)' do
      existing = { 'pails' => [find_pail('1', 'F1', extra: registrar_data)] }
      incoming = { 'pails' => [find_pail('1', 'F1', type: 'Loom weight')] }

      find = described_class.merge(existing, incoming)['pails'][0]['finds'][0]

      expect(find).to include('type' => 'Loom weight', 'cover_key' => 'a.jpg',
                              'state' => 'registration complete', 'photos' => [{ 'key' => 'a.jpg' }])
    end

    it 'keeps unedited pails/finds intact and honours the form set' do
      existing = { 'pails' => [find_pail('1', 'F1', extra: { 'photos' => ['x'] }),
                               find_pail('2', 'F2', extra: { 'photos' => ['y'] })] }
      incoming = { 'pails' => [find_pail('2', 'F2', type: 'Sherd')] }

      merged = described_class.merge(existing, incoming)

      expect(merged['pails'].map { |p| p['pail_number'] }).to eq(['2'])
      expect(merged['pails'][0]['finds'][0]).to include('type' => 'Sherd', 'photos' => ['y'])
    end

    it 'preserves locus photo metadata the form did not render' do
      existing = { 'photos' => [{ 'key' => 'p1', 'type' => 'official', 'note' => 'north' }] }
      incoming = { 'photos' => [{ 'key' => 'p1', 'caption' => 'updated' }] }

      merged = described_class.merge(existing, incoming)

      expect(merged['photos'][0]).to include('type' => 'official', 'note' => 'north', 'caption' => 'updated')
    end

    it 'lets the form replace id-less arrays (levels) so deletes stick' do
      existing = { 'levels' => [{ 'reading' => 1 }, { 'reading' => 2 }] }
      incoming = { 'levels' => [{ 'reading' => 1 }] }

      expect(described_class.merge(existing, incoming)['levels']).to eq([{ 'reading' => 1 }])
    end

    it 'deep-merges hash fields and preserves the _rev for the save' do
      existing = { '_rev' => '5-abc', 'general' => { 'a' => '1', 'b' => '2' } }
      incoming = { 'general' => { 'b' => '9' } }

      merged = described_class.merge(existing, incoming)

      expect(merged).to include('_rev' => '5-abc', 'general' => { 'a' => '1', 'b' => '9' })
    end
  end

  def registrar_data
    { 'photos' => [{ 'key' => 'a.jpg' }], 'cover_key' => 'a.jpg', 'state' => 'registration complete' }
  end

  def find_pail(pail_number, field_number, type: 'Bead', extra: {})
    { 'pail_number' => pail_number,
      'finds' => [{ 'field_number' => field_number, 'type' => type }.merge(extra)] }
  end
end
