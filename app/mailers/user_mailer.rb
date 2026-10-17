# Mailer methods take a user id string (User#id_as_string) rather than a User:
# deliver_later has to serialize its arguments, and User isn't an ActiveRecord model.
class UserMailer < ApplicationMailer
  def email_verification(user_id)
    @user = User.find(user_id)
    @url = verify_email_url(token: @user.email_verification_token)
    mail to: @user.email, subject: 'Confirm your OpenDig account'
  end

  def password_reset(user_id)
    @user = User.find(user_id)
    @url = edit_password_reset_url(token: @user.password_reset_token)
    mail to: @user.email, subject: 'Reset your OpenDig password'
  end

  # Sanity check for SMTP settings (see `rake mail:test`).
  def test_message(to)
    mail to: to, subject: 'OpenDig test email', body: "If you can read this, OpenDig can send email (#{Time.current.iso8601})."
  end
end
