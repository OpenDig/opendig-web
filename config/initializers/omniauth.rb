Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV['GOOGLE_CLIENT_ID'], ENV['GOOGLE_CLIENT_SECRET'], {
    scope: 'openid,email,profile',
    prompt: 'select_account',
    image_aspect_ratio: 'square',
    image_size: 50
  }

  if Rails.env.development?
    provider :developer,
             fields: [:name, :email]

    configure do |config|
      config.allowed_request_methods = [:get, :post]
    end
  end
end
