require 'rails_helper'

RSpec.describe PhotoName, type: :model do
  describe '.parse' do
    subject(:name) { described_class.parse('B26.08.92.001.0621_Progress.JPG') }

    it 'splits the convention into its parts' do
      expect(name).to be_valid
      expect(name.season).to eq('B26')
      expect(name.area).to eq('08')
      expect(name.square).to eq('92')
      expect(name.sequence).to eq('001')
      expect(name.date).to eq('0621')
      expect(name.subject).to eq('Progress')
      expect(name.ext).to eq('.JPG')
    end

    it 'derives the calendar year from the season code' do
      expect(name.season_year).to eq(2026)
    end

    it 'builds the locus code' do
      expect(name.locus_code).to eq('08.92.001')
    end

    it 'tolerates a missing subject' do
      n = described_class.parse('B26.08.92.001.0621.jpg')
      expect(n).to be_valid
      expect(n.subject).to be_nil
    end

    it 'marks non-conforming filenames invalid' do
      n = described_class.parse('IMG_1234.jpg')
      expect(n).not_to be_valid
      expect(n.suggest_loci([{ area: '8', square: '92', code: '1' }])).to eq([])
    end
  end

  describe '#suggest_loci' do
    subject(:name) { described_class.parse('B26.08.92.001.0621_Progress.JPG') }

    let(:loci) do
      [
        { area: '08', square: '92', code: '1', id: 'locA' },
        { area: '8',  square: '92', code: '2', id: 'locB' }, # numeric-normalized match
        { area: '9',  square: '1',  code: '1', id: 'locZ' },
      ]
    end

    it 'returns ALL loci in the photo area+square (a photo can belong to many)' do
      expect(name.suggest_loci(loci).map { |l| l[:id] }).to eq(%w[locA locB])
    end

    it 'returns nothing when no locus shares the area/square' do
      expect(name.suggest_loci([{ area: '1', square: '1', code: '1', id: 'x' }])).to eq([])
    end
  end
end
