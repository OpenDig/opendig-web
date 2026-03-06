require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  fixtures :users

  describe "GET create" do
      before do
      request.env['omniauth.auth'] = {
        'uid' => users(:viewer).uid,
        'provider' => users(:viewer).provider,
        'info' => {
          'email' => users(:viewer).email
        }
      }
    end

    it "creates a new user if one doesn't exist" do
      request.env['omniauth.auth']['uid'] = '12345'
      expect {
        get :create, params: { provider: 'test_provider' }
      }.to change(User, :count).by(1)

      user = User.last
      expect(user.uid).to eq('12345')
      expect(user.provider).to eq('test_provider')
      expect(user.email).to eq(users(:viewer).email)
    end

    it "finds an existing user and logs them in" do
      expect {
        get :create, params: { provider: 'test_provider' }
      }.to_not change(User, :count)

      expect(session[:user_id]).to eq(users(:viewer).id)
    end
  end

  describe "DELETE destroy" do
      before do
      session[:user_id] = users(:viewer).id
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
