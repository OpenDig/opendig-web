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

    it 'emails the invitee' do
      session[:user_id] = users[:dig_director].id

      expect do
        post :create, params: { invitation: { email: 'new@example.com', role: 'registrar' } }
      end.to have_enqueued_mail(InvitationMailer, :invitation).with('opendig', 'new@example.com')
    end

    context 'when mail is not configured' do
      include_context 'without mail'

      it 'creates the invitation without emailing' do
        session[:user_id] = users[:dig_director].id

        expect do
          post :create, params: { invitation: { email: 'new@example.com', role: 'registrar' } }
        end.not_to have_enqueued_mail

        expect(Invitation.pending_for('new@example.com')).to be_present
      end
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

  describe 'POST resend' do
    before do
      Invitation.new(email: 'new@example.com', project: 'opendig', role: 'registrar', invited_by: 'a@example.com').save!
      session[:user_id] = users[:dig_director].id
    end

    it 'emails the invitation again' do
      expect do
        post :resend, params: { email: 'new@example.com' }
      end.to have_enqueued_mail(InvitationMailer, :invitation).with('opendig', 'new@example.com')

      expect(flash[:notice]).to eq('Invitation re-sent to new@example.com')
      expect(response).to redirect_to(controller.manage_users_admin_index_path)
    end

    it 'reports an invitation that no longer exists' do
      expect { post :resend, params: { email: 'gone@example.com' } }.not_to have_enqueued_mail

      expect(flash[:alert]).to match(/no longer exists/)
    end

    context 'when mail is not configured' do
      include_context 'without mail'

      it 'explains that it cannot send' do
        expect { post :resend, params: { email: 'new@example.com' } }.not_to have_enqueued_mail

        expect(flash[:alert]).to match(/isn't set up yet/)
      end
    end

    it 'forbids a registrar' do
      session[:user_id] = users[:registrar].id

      expect { post :resend, params: { email: 'new@example.com' } }.not_to have_enqueued_mail
      expect(response).to redirect_to(controller.root_path)
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
