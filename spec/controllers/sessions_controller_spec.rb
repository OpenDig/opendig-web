require 'rails_helper'
require 'securerandom'

RSpec.describe SessionsController, type: :controller do
  let (:users) { load_user_fixtures }

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

    it "creates a new user if one doesn't exist" do
      request.env['omniauth.auth'] = {
        'uid' => SecureRandom.uuid,
        'provider' => users[:viewer].provider,
        'info' => {
          'name' => users[:viewer].name,
          'email' => users[:viewer].email
        },
        'roles' => users[:viewer].roles
      }

      expect {
        get :create, params: { provider: 'test_provider' }
      }.to change { User.find_all.size }.by(1)

      auth = request.env['omniauth.auth']
      user = User.find_by(provider: auth['provider'], uid: auth['uid'])
      expect(user.uid).to eq(request.env['omniauth.auth']['uid'])
      expect(user.provider).to eq(auth['provider'])
      expect(user.email).to eq(users[:viewer].email)
    end

    it "finds an existing user and logs them in" do
      request.env['omniauth.auth'] = {
        'uid' => users[:viewer].uid,
        'provider' => users[:viewer].provider,
        'info' => {
          'email' => users[:viewer].email,
          'name' => users[:viewer].name

        }
      }

      expect {
        get :create, params: { provider: 'test_provider' }
      }.to_not change(User.find_all, :size)

      expect(session[:user_id]).to eq(users[:viewer].id)
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
