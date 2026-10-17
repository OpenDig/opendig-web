require 'rails_helper'

RSpec.describe PasswordResetsController, type: :controller do
  let(:user) { User.register(email: 'reset@example.com', password: 'oldpassword', name: 'Reset') }

  before do
    user.save
    User.for_email('reset@example.com').verify_email!
  end

  after do
    doc = begin
      CouchDB.auth_db.get('email__reset@example.com')
    rescue StandardError
      nil
    end
    CouchDB.auth_db.delete_doc(doc) if doc
  end

  describe 'POST create' do
    it 'emails a reset link to a known address' do
      expect do
        post :create, params: { email: 'Reset@Example.com' }
      end.to have_enqueued_mail(UserMailer, :password_reset).with('email__reset@example.com')

      expect(response).to redirect_to(controller.login_path)
    end

    it 'gives the same answer for an unknown address, without sending anything' do
      expect do
        post :create, params: { email: 'nobody@example.com' }
      end.not_to have_enqueued_mail

      expect(response).to redirect_to(controller.login_path)
      expect(flash[:notice]).to match(/If nobody@example.com has an OpenDig account/)
    end
  end

  describe 'GET new' do
    render_views

    it 'renders the request form' do
      get :new

      expect(response.body).to include('Send reset link')
    end
  end

  describe 'GET edit' do
    render_views

    it 'shows the form for a valid link' do
      get :edit, params: { token: user.password_reset_token }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Choose a new password', 'reset@example.com')
    end

    it 'turns away an invalid link' do
      get :edit, params: { token: 'nope' }

      expect(response).to redirect_to(controller.new_password_reset_path)
    end
  end

  describe 'PATCH update' do
    it 'changes the password and signs the user in' do
      patch :update, params: { token: user.password_reset_token, password: 'newpassword', password_confirmation: 'newpassword' }

      expect(User.authenticate_email('reset@example.com', 'newpassword')).to be_truthy
      expect(User.authenticate_email('reset@example.com', 'oldpassword')).to be_nil
      expect(session[:user_id]).to eq(user.id)
      expect(response).to redirect_to(controller.root_path)
    end

    it 'only works once per link' do
      token = user.password_reset_token
      patch :update, params: { token: token, password: 'newpassword', password_confirmation: 'newpassword' }
      session.delete(:user_id)

      patch :update, params: { token: token, password: 'otherpassword', password_confirmation: 'otherpassword' }

      expect(User.authenticate_email('reset@example.com', 'otherpassword')).to be_nil
      expect(response).to redirect_to(controller.new_password_reset_path)
    end

    it 'refuses a blank password' do
      patch :update, params: { token: user.password_reset_token, password: '', password_confirmation: '' }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(User.authenticate_email('reset@example.com', 'oldpassword')).to be_truthy
    end

    it 'confirms an unconfirmed account, since the link proves ownership of the address' do
      reloaded = User.for_email('reset@example.com')
      reloaded.update!({ pending_verification: true })

      patch :update, params: { token: reloaded.password_reset_token, password: 'newpassword', password_confirmation: 'newpassword' }

      expect(User.for_email('reset@example.com')).not_to be_pending_verification
    end
  end

  context 'when mail is not configured' do
    include_context 'without mail'

    it 'is unavailable' do
      expect { post :create, params: { email: 'reset@example.com' } }.not_to have_enqueued_mail

      expect(response).to redirect_to(controller.login_path)
      expect(flash[:error]).to match(/isn't available/)
    end
  end
end
