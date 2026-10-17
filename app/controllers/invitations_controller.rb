class InvitationsController < ApplicationController
  before_action :require_manage_users

  # Create (or update) a pending invitation for the current project.
  def create
    role = invitation_params[:role]
    unless current_user.can_assign_role?(role)
      flash[:alert] = "You are not allowed to assign the #{role.to_s.humanize.downcase} role"
      return redirect_to manage_users_admin_index_path
    end

    @invitation = Invitation.new(
      email: invitation_params[:email],
      project: current_dig,
      role: role,
      scopes: invitation_params[:scopes],
      invited_by: current_user.email
    )

    if @invitation.save
      applied = @invitation.apply_to_existing_users!
      InvitationMailer.invitation(@invitation.project, @invitation.email).deliver_later if mail_enabled?
      flash[:notice] = if applied.any?
                         "#{@invitation.email} already has an account, so they're now #{role.to_s.humanize.downcase}"
                       elsif mail_enabled?
                         "Invitation sent to #{@invitation.email}"
                       else
                         "Invitation created for #{@invitation.email}"
                       end
    else
      flash[:alert] = "Could not create invitation: #{@invitation.errors.full_messages.to_sentence}"
    end
    redirect_to manage_users_admin_index_path
  end

  # Revoke a pending invitation. Keyed by email within the current project (the
  # email contains dots, so it is passed as a query param rather than a path id).
  def destroy
    Invitation.find(current_dig, params[:email])&.revoke!
    flash[:notice] = 'Invitation revoked'
    redirect_to manage_users_admin_index_path
  end

  # Email a pending invitation again. Keyed by email like #destroy.
  def resend
    invitation = Invitation.find(current_dig, params[:email])
    if invitation.nil? || !invitation.pending?
      flash[:alert] = 'That invitation no longer exists'
    elsif !mail_enabled?
      flash[:alert] = "Email isn't set up yet, so the invitation can't be sent. #{invitation.email} can still sign up " \
                      'or sign in with that address to get access.'
    else
      InvitationMailer.invitation(invitation.project, invitation.email).deliver_later
      flash[:notice] = "Invitation re-sent to #{invitation.email}"
    end
    redirect_to manage_users_admin_index_path
  end

  private

  def invitation_params
    params.require(:invitation).permit(:email, :role, scopes: [])
  end
end
