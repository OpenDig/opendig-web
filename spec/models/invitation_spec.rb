require 'rails_helper'

RSpec.describe Invitation, type: :model do
  let(:attrs) { { email: 'Alice@Example.com', project: 'opendig', role: 'registrar', invited_by: 'admin@example.com' } }

  after { Invitation.find('opendig', 'alice@example.com')&.revoke! }

  describe 'validations' do
    it 'is valid with an email, project, and known role' do
      expect(Invitation.new(attrs)).to be_valid
    end

    it 'requires a valid email' do
      expect(Invitation.new(attrs.merge(email: 'not-an-email'))).not_to be_valid
    end

    it 'requires a known role' do
      expect(Invitation.new(attrs.merge(role: 'wizard'))).not_to be_valid
    end

    it 'downcases the email' do
      expect(Invitation.new(attrs).email).to eq('alice@example.com')
    end
  end

  describe 'persistence and lookup' do
    it 'is found as pending for its email and project' do
      Invitation.new(attrs).save!

      expect(Invitation.pending_for('alice@example.com').map(&:role)).to include('registrar')
      expect(Invitation.for_project('opendig').map(&:email)).to include('alice@example.com')
    end

    it 're-inviting the same email/project updates instead of duplicating' do
      Invitation.new(attrs).save!
      Invitation.new(attrs.merge(role: 'area_supervisor', scopes: ['1'])).save!

      invites = Invitation.for_project('opendig').select { |i| i.email == 'alice@example.com' }
      expect(invites.size).to eq(1)
      expect(invites.first.role).to eq('area_supervisor')
      expect(invites.first.scopes).to eq(['1'])
    end

    it 'accept! flips the status so it is no longer pending' do
      invitation = Invitation.new(attrs)
      invitation.save!
      invitation.accept!

      expect(Invitation.pending_for('alice@example.com')).to be_empty
    end

    it 'revoke! deletes it' do
      invitation = Invitation.new(attrs)
      invitation.save!
      invitation.revoke!

      expect(Invitation.find('opendig', 'alice@example.com')).to be_nil
    end
  end
end
