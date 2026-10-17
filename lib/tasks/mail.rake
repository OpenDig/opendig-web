namespace :mail do
  desc 'Send a test email to check SMTP settings: rake "mail:test[you@example.com]"'
  task :test, [:to] => :environment do |_t, args|
    abort 'Usage: rake "mail:test[you@example.com]"' if args[:to].blank?

    UserMailer.test_message(args[:to]).deliver_now
    puts "Sent a test email to #{args[:to]} via #{ActionMailer::Base.smtp_settings[:address]}"
  end
end
