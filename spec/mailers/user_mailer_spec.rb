require 'rails_helper'

RSpec.describe UserMailer do
  let(:user) { User.register(email: 'mail@example.com', password: 'supersecret', name: 'Mail Person') }

  before { user.save }

  after do
    doc = begin
      CouchDB.auth_db.get('email__mail@example.com')
    rescue StandardError
      nil
    end
    CouchDB.auth_db.delete_doc(doc) if doc
  end

  it 'sends a confirmation link that verifies the account' do
    mail = described_class.email_verification(user.id_as_string)

    expect(mail.to).to eq(['mail@example.com'])
    token = mail.text_part.body.to_s[%r{/verify_email\?token=(\S+)}, 1]
    expect(User.find_by_token(CGI.unescape(token), purpose: :email_verification)).to eq(user)
  end

  it 'sends a password reset link' do
    mail = described_class.password_reset(user.id_as_string)

    expect(mail.to).to eq(['mail@example.com'])
    token = mail.text_part.body.to_s[%r{/password/reset\?token=(\S+)}, 1]
    expect(User.find_by_token(CGI.unescape(token), purpose: :password_reset)).to eq(user)
  end
end
