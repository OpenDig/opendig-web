require 'rails_helper'

shared_examples_for 'authentication provider' do |provider|
  context "- logging in with #{provider}" do
    it 'signs a user in upon successful authentication' do
      test_user = users(provider.to_s)
      initial_user_count = User.count

      get auth_callback_path(provider: provider)

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include(test_user.email) # verify the user info appears
      expect(User.count).to eq(initial_user_count) # No new user should be created
    end

    it 'creates a new user if one does not exist' do
      initial_user_count = User.count
      test_email = 'new_user@example.com'
      OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
        uid: 'new_uid_12345',
        provider: provider.to_s,
        info: {
          name: 'New User',
          email: test_email
        }
      )

      get auth_callback_path(provider: provider)

      expect(response).to redirect_to(root_path)
      follow_redirect!
      expect(response.body).to include(test_email)
      expect(User.count).to eq(initial_user_count + 1) # A new user should be created
    end

    it 'handles authentication failure' do
      OmniAuth.config.mock_auth[provider.to_sym] = :invalid_credentials # Mock a failure

      get auth_callback_path(provider: provider)
      expect(response).to redirect_to(auth_failure_path(message: 'invalid_credentials', strategy: provider))
      follow_redirect!
      expect(response).to redirect_to(root_path)

      follow_redirect!
      expect(response.body).to include('Authentication failed')
    end
  end
end

{
  'GitHub' => :github,
  'Google' => :google_oauth2,
  'Microsoft' => :microsoft_office365
}.each do |provider_formatted, provider_id|
  RSpec.describe "#{provider_formatted} authentication", type: :request do
    fixtures :users

    before do
      # Load users
      OmniAuth.config.test_mode = true
      test_user = users(provider_id.to_s)
      test_auth_hash = {
        uid: test_user['uid'],
        provider: test_user['provider'],
        info: {
          name: test_user['name'] || '',
          email: test_user['email']
        }
      }
      OmniAuth.config.mock_auth[provider_id] = OmniAuth::AuthHash.new(test_auth_hash)
    end

    it_behaves_like 'authentication provider', provider_id

    after(:each) do
      # Ensure no user is signed in
      delete logout_path
    end
  end
end
