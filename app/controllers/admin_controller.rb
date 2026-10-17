class AdminController < ApplicationController
  before_action :require_manage_users
  # Accounts are shared across every dig, so only a superuser may delete them.
  before_action :require_superuser, only: :destroy_users

  def manage_users
    # Roles are per-project; show each user's role for the project we're on.
    @users = User.find_all.each { |user| user.current_dig = current_dig }
    @invitations = Invitation.for_project(current_dig)
    @invitation = Invitation.new(project: current_dig, role: User.default_role)
  end

  def update_user
    @user = User.find(params[:id])
    return head :not_found unless @user

    @user.current_dig = current_dig

    requested_role = params.dig(:user, :role)
    if requested_role.present? && !current_user.can_assign_role?(requested_role)
      flash[:alert] = "You are not allowed to assign the #{requested_role.to_s.humanize.downcase} role"
    elsif @user.update(user_params)
      # Setting the role directly replaces any invitation still waiting for this
      # person; otherwise it would overwrite this role at their next sign-in.
      pending = @user.email.present? && Invitation.find(current_dig, @user.email)
      pending.revoke! if pending&.pending?
      flash[:notice] = "#{@user.name} is now #{@user.role.humanize.downcase}"
    else
      flash[:alert] = "Failed to update #{@user.name}"
    end
    # Reopen this user's row, e.g. to pick scopes for a supervisor role.
    redirect_to manage_users_admin_index_path(open: @user.id_as_string)
  end

  # Delete the selected accounts (e.g. spam signups). Never deletes the current
  # user or a superuser.
  def destroy_users
    ids = Array(params[:user_ids]).compact_blank - [current_user.id_as_string]
    users = ids.filter_map { |id| User.find(id) }.reject(&:superuser?)
    users.each(&:destroy!)

    flash[:notice] = "Deleted #{helpers.pluralize(users.size, 'user')}"
    redirect_to manage_users_admin_index_path
  end

  private

  def user_params
    params.require(:user).permit(:role, scopes: [])
  end
end
