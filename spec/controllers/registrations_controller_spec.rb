require 'rails_helper'

RSpec.describe RegistrationsController, type: :controller do
  after do
    doc = begin
      CouchDB.auth_db.get('email__new@example.com')
    rescue StandardError
      nil
    end
    CouchDB.auth_db.delete_doc(doc) if doc
  end

  describe 'POST create' do
    it 'creates an email account and signs the user in' do
      expect do
        post :create, params: { name: 'New User', email: 'New@Example.com',
                                password: 'supersecret', password_confirmation: 'supersecret' }
      end.to change { User.find_all.size }.by(1)

      expect(session[:user_id]).to be_present
      expect(response).to redirect_to(controller.root_path)
      expect(User.authenticate_email('new@example.com', 'supersecret')).to be_truthy
    end

    it 'rejects a too-short password and does not sign in' do
      post :create, params: { name: 'New User', email: 'new@example.com',
                              password: 'short', password_confirmation: 'short' }

      expect(session[:user_id]).to be_nil
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
