require 'rails_helper'

RSpec.describe InvitationMailer do
  before do
    Invitation.new(email: 'invitee@example.com', project: 'balua', role: 'registrar', invited_by: 'director@example.com').save!
  end

  after { Invitation.find('balua', 'invitee@example.com')&.revoke! }

  it 'links the invitee to the project and to signup' do
    mail = described_class.invitation('balua', 'invitee@example.com')

    expect(mail.to).to eq(['invitee@example.com'])
    expect(mail.subject).to include('Balua')
    body = mail.text_part.body.to_s
    expect(body).to include('http://balua.example.com/')
    expect(body).to include('/signup?email=invitee%40example.com')
  end
end
