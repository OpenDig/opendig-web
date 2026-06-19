# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'rspec/rails'
# Add additional requires below this line. Rails is not loaded until this point!

# Configure CouchDB
CouchDB.set_env! 'test'

# Editing is gated by EDITING_ENABLED (ApplicationController#check_editing_mode).
# Enable it for the suite so controller specs can exercise create/edit/update
# actions regardless of the host environment (CI does not set this var).
ENV['EDITING_ENABLED'] ||= 'true'

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }
RSpec.configure do |config|
  # Load specific Rails helpers needed
  config.include ActiveSupport::Testing::TimeHelpers

  # The suite operates against a single project ("opendig"). Make it the current
  # CouchDB project for every example so model code that calls `CouchDB.main_db`
  # (and User role lookups, which default to CouchDB.current_project) resolves it.
  config.before(:each) do
    CouchDB.current_project = 'opendig'
  end

  # Controller examples run a real request through `resolve_project`, which reads
  # the subdomain. Give them a host whose subdomain is the test project, and treat
  # that project as existing (avoids a live _all_dbs lookup).
  config.before(:each, type: :controller) do
    request.host = 'opendig.example.com'
    allow(Project).to receive(:exists?).with('opendig').and_return(true)
  end

  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # You can uncomment this line to turn off ActiveRecord support entirely.
  config.use_active_record = false

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, type: :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")
end

def load_user_fixtures
  @load_user_fixtures ||= YAML.load_file(Rails.root.join("spec/fixtures/users.yml")).transform_values do |attrs|
    User.new(attrs, persist: false) # Load into memory only (much faster than saving to DB)
  end.to_h.with_indifferent_access
end
