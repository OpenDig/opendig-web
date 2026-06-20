require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  let(:users) { load_user_fixtures }

  describe "GET create" do
    before do
      request.env['omniauth.auth'] = {
        'uid' => users[:viewer].uid,
        'provider' => users[:viewer].provider,
        'info' => {
          'name' => users[:viewer].name,
          'email' => users[:viewer].email
        }
      }
    end

    let(:viewer_auth_hash) do
      {
        'uid' => users[:viewer].uid,
        'provider' => users[:viewer].provider,
        'info' => {
          'name' => users[:viewer].name,
          'email' => users[:viewer].email
        }
      }
    end

    it "creates a new user if one doesn't exist" do
      request.env['omniauth.auth'] = viewer_auth_hash.merge({ 'uid' => 'random' })

      expect { get :create, params: { provider: 'test_provider' } }.to change { User.find_all.size }.by(1)

      auth = request.env['omniauth.auth']
      user = User.find_by(provider: auth['provider'], uid: auth['uid'])
      expect(user.uid).to eq(request.env['omniauth.auth']['uid'])
      expect(user.provider).to eq(auth['provider'])
      expect(user.email).to eq(users[:viewer].email)
    end

    it "finds an existing user and logs them in" do
      request.env['omniauth.auth'] = viewer_auth_hash

      expect do
        get :create, params: { provider: 'test_provider' }
      end.not_to change(User.find_all, :size)

      expect(session[:user_id]).to eq(users[:viewer].id)
    end
  end

  describe "post-login redirect (apex OAuth callback -> originating subdomain)" do
    let(:auth_hash) do
      { 'uid' => users[:viewer].uid, 'provider' => users[:viewer].provider,
        'info' => { 'name' => users[:viewer].name, 'email' => users[:viewer].email } }
    end

    before do
      request.host = 'opendig.org'
      request.env['omniauth.auth'] = auth_hash
    end

    it "returns the user to a subdomain origin on our registrable domain" do
      request.env['omniauth.origin'] = 'https://balua.opendig.org/'
      get :create, params: { provider: 'test_provider' }
      expect(response).to redirect_to('https://balua.opendig.org/')
    end

    it "ignores a foreign origin (open-redirect guard) and falls back to root" do
      request.env['omniauth.origin'] = 'https://evil.example.com/'
      get :create, params: { provider: 'test_provider' }
      expect(response).to redirect_to(controller.root_path)
    end

    it "falls back to root when no origin is present" do
      get :create, params: { provider: 'test_provider' }
      expect(response).to redirect_to(controller.root_path)
    end
  end

  describe "applying invitations on login" do
    after { Invitation.find('opendig', 'invited@example.com')&.revoke! }

    it "applies a pending invitation matching the signed-in email" do
      Invitation.new(email: 'invited@example.com', project: 'opendig', role: 'registrar', invited_by: 'admin@example.com').save!
      request.env['omniauth.auth'] = {
        'uid' => 'invited-uid', 'provider' => 'test_provider',
        'info' => { 'name' => 'Invited Person', 'email' => 'invited@example.com' }
      }

      get :create, params: { provider: 'test_provider' }

      user = User.find_by(provider: 'test_provider', uid: 'invited-uid')
      user.current_dig = 'opendig'
      expect(user.role).to eq('registrar')
      expect(Invitation.pending_for('invited@example.com')).to be_empty
    end
  end

  describe "POST password_login" do
    before { User.register(email: 'login@example.com', password: 'supersecret', name: 'Login').save }
    after do
      doc = CouchDB.auth_db.get('email__login@example.com') rescue nil
      CouchDB.auth_db.delete_doc(doc) if doc
    end

    it "signs in with correct email and password" do
      post :password_login, params: { email: 'login@example.com', password: 'supersecret' }

      expect(session[:user_id]).to be_present
      expect(response).to redirect_to(controller.root_path)
    end

    it "rejects a wrong password" do
      post :password_login, params: { email: 'login@example.com', password: 'nope' }

      expect(session[:user_id]).to be_nil
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE destroy" do
    before do
      session[:user_id] = users[:viewer].id
    end

    it "logs the user out by clearing the session" do
      delete :destroy

      expect(session[:user_id]).to be_nil
    end
  end

  describe "GET failure" do
    it "redirects to root path with error flash" do
      get :failure

      expect(flash[:error]).to eq('Authentication failed, please try again.')
      expect(response).to redirect_to(controller.root_path)
    end
  end
end
