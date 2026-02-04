# Test mode
OmniAuth.config.test_mode = true

# Test data
%I[google_oauth2 github microsoft_office365].each do |provider|
  OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(
    {
      provider: provider.to_s,
      uid: '12345',
      info: {
        name: 'John Doe',
        email: 'john@example.com'
      }
    }
  )
end
