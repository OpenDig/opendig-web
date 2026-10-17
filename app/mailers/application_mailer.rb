class ApplicationMailer < ActionMailer::Base
  default from: -> { "OpenDig <#{ENV.fetch('SENDER_EMAIL', 'no-reply@opendig.org')}>" }
  layout 'mailer'
end
