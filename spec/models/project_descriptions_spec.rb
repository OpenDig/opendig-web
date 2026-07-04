require 'rails_helper'

RSpec.describe ProjectDescriptions do
  # Unit-test the lookup add/delete merge logic without CouchDB by stubbing the
  # effective/override/save boundary.
  before do
    allow(described_class).to receive_messages(
      effective: { 'lookups' => { 'decoration' => %w[Painted Incised] } },
      override: {}
    )
  end

  describe '.add_lookup_value' do
    it 'appends to the effective list, seeding the override so base values survive' do
      expect(described_class).to receive(:save) do |_project, override|
        expect(override['lookups']['decoration']).to eq(%w[Painted Incised Trailed])
      end
      described_class.add_lookup_value('proj', 'decoration', 'Trailed')
    end

    it 'is idempotent — a value already present is not re-added' do
      expect(described_class).not_to receive(:save)
      described_class.add_lookup_value('proj', 'decoration', 'Painted')
    end

    it 'ignores a blank value' do
      expect(described_class).not_to receive(:save)
      described_class.add_lookup_value('proj', 'decoration', '  ')
    end

    it 'seeds a brand-new lookup (e.g. custom_colors) from empty' do
      expect(described_class).to receive(:save) do |_project, override|
        expect(override['lookups']['custom_colors']).to eq(%w[Iridescent])
      end
      described_class.add_lookup_value('proj', 'custom_colors', 'Iridescent')
    end
  end

  describe '.remove_lookup_value' do
    it 'removes a present value' do
      expect(described_class).to receive(:save) do |_project, override|
        expect(override['lookups']['decoration']).to eq(%w[Incised])
      end
      described_class.remove_lookup_value('proj', 'decoration', 'Painted')
    end

    it 'does nothing when the value is absent' do
      expect(described_class).not_to receive(:save)
      described_class.remove_lookup_value('proj', 'decoration', 'Nonexistent')
    end
  end
end
