# OmniAuth.config.full_host = Rails.env.production? ? 'https://domain.com' : 'http://localhost:3000'
# OmniAuth.config.allowed_request_methods = %i[get]

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], {
    scope: 'openid,email,profile',
    prompt: 'select_account',
    image_aspect_ratio: 'square',
    image_size: 50
  }

  provider :github, ENV['GITHUB_CLIENT_ID'], ENV['GITHUB_CLIENT_SECRET'], scope: "read:user,user:email"

  provider :microsoft_office365, ENV['MICROSOFT_CLIENT_ID'], ENV['MICROSOFT_CLIENT_SECRET'], {
    scope: 'openid offline_access User.Read'
  }

  if Rails.env.development?
    provider :developer,
      fields: [:name, :email, :access_level],
      uid_field: :email
    
    configure do |config|
      config.allowed_request_methods = [:get, :post]
    end
  end
end
