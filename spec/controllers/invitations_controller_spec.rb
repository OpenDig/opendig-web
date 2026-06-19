require 'rails_helper'

RSpec.describe InvitationsController, type: :controller do
  let(:users) { load_user_fixtures }

  after { Invitation.find('opendig', 'new@example.com')&.revoke! }

  describe 'POST create' do
    it 'lets a dig director invite a non-superuser role for the current project' do
      session[:user_id] = users[:dig_director].id

      post :create, params: { invitation: { email: 'new@example.com', role: 'registrar' } }

      pending = Invitation.pending_for('new@example.com')
      expect(pending.map(&:role)).to eq(['registrar'])
      expect(pending.first.project).to eq('opendig')
      expect(response).to redirect_to(controller.manage_users_admin_index_path)
    end

    it 'blocks a dig director from inviting a superuser' do
      session[:user_id] = users[:dig_director].id

      post :create, params: { invitation: { email: 'new@example.com', role: 'superuser' } }

      expect(Invitation.pending_for('new@example.com')).to be_empty
      expect(flash[:alert]).to match(/not allowed/i)
    end

    it 'forbids a registrar from inviting' do
      session[:user_id] = users[:registrar].id

      post :create, params: { invitation: { email: 'new@example.com', role: 'registrar' } }

      expect(response).to redirect_to(controller.root_path)
      expect(Invitation.pending_for('new@example.com')).to be_empty
    end
  end

  describe 'DELETE destroy' do
    it 'revokes a pending invitation' do
      Invitation.new(email: 'new@example.com', project: 'opendig', role: 'registrar', invited_by: 'a@example.com').save!
      session[:user_id] = users[:superuser].id

      delete :destroy, params: { email: 'new@example.com' }

      expect(Invitation.find('opendig', 'new@example.com')).to be_nil
    end
  end
end
