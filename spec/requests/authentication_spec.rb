require 'rails_helper'

RSpec.describe 'Authentication', type: :request do
  it 'creates a user and signs them in upon successful authentication' do
    get '/auth/github/callback'
    expect(response).to redirect_to(root_path) # or wherever you redirect after login

    follow_redirect!
    expect(response.body).to include('jane@example.com') # verify the user info appears
    expect(User.count).to eq(1)
  end

  it 'handles authentication failure' do
    OmniAuth.config.mock_auth[:github] = :invalid_credentials # Mock a failure

    get '/auth/github/callback'
    expect(response).to redirect_to(root_path)

    follow_redirect!
    expect(response.body).to include('Authentication failed')
  end
end
