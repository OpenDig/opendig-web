require 'rails_helper'

RSpec.describe EmailVerificationsController, type: :controller do
  let(:user) { User.register(email: 'verify@example.com', password: 'supersecret', name: 'Verify') }

  before { user.save }

  after do
    doc = begin
      CouchDB.auth_db.get('email__verify@example.com')
    rescue StandardError
      nil
    end
    CouchDB.auth_db.delete_doc(doc) if doc
  end

  describe 'GET show' do
    it 'confirms the account and signs the user in' do
      get :show, params: { token: user.email_verification_token }

      expect(User.for_email('verify@example.com')).not_to be_pending_verification
      expect(session[:user_id]).to eq(user.id)
      expect(response).to redirect_to(controller.root_path)
    end

    it 'rejects an expired link' do
      token = user.email_verification_token

      travel 4.days do
        get :show, params: { token: token }
      end

      expect(User.for_email('verify@example.com')).to be_pending_verification
      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to(controller.login_path)
    end

    it 'rejects a tampered link' do
      get :show, params: { token: 'not-a-real-token' }

      expect(session[:user_id]).to be_nil
      expect(response).to redirect_to(controller.login_path)
    end
  end
end
