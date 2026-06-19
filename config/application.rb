require_relative 'boot'

require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'action_cable/engine'
require 'sprockets/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module OpendigWeb7
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    config.eager_load_paths << Rails.root.join('lib')
    config.assets.precompile += ['pdf.css']

    # Projects are selected by subdomain (e.g. balua.opendig.org -> "balua").
    # Both opendig.org and lvh.me (dev) are two-label registrable domains, so a
    # tld_length of 1 yields the project key as request.subdomain for each.
    config.action_dispatch.tld_length = 1
    config.autoload_paths += Dir["#{Rails.root}/lib/**/"] if Rails.env == 'development'
    config.assets.css_compressor = nil

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
