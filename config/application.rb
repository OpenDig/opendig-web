require_relative "boot"

require "rails/all"

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
    config.eager_load_paths << Rails.root.join("lib")
    config.assets.precompile += ['pdf.css']
    config.autoload_paths += Dir["#{Rails.root}/lib/**/"] if Rails.env == 'development'
    config.assets.css_compressor = nil

    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
