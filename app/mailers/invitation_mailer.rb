class InvitationMailer < ApplicationMailer
  # Takes the invitation's key (project + email) rather than the Invitation, so
  # deliver_later can serialize it.
  def invitation(project, email)
    @invitation = Invitation.find(project, email)
    @project_url = root_url(subdomain: project)
    @signup_url = signup_url(email: email)
    mail to: email, subject: "You've been invited to #{project.to_s.humanize} on OpenDig"
  end
end
