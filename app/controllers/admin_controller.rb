class AdminController < ApplicationController
  before_action :require_manage_users

  def manage_users
    # Roles are per-project; show each user's role for the project we're on.
    @users = User.find_all.each { |user| user.current_dig = current_dig }
    @invitations = Invitation.for_project(current_dig)
    @invitation = Invitation.new(project: current_dig, role: User.default_role)
  end

  def update_user
    @user = User.find(params[:id])
    @user.current_dig = current_dig

    requested_role = params.dig(:user, :role)
    if requested_role.present? && !current_user.can_assign_role?(requested_role)
      flash.now[:alert] = "You are not allowed to assign the #{requested_role.to_s.humanize.downcase} role"
      return respond_to do |format|
        format.html { render partial: 'admin/manage_users_role_form', user: @user, open: true, layout: false }
        format.turbo_stream
      end
    end

    if @user.update(user_params)
      respond_to do |format|
        flash.now[:notice] = "User updated successfully"
        format.html { render partial: 'admin/manage_users_role_form', user: @user, open: true, layout: false }
        format.turbo_stream
      end
    else
      respond_to do |format|
        flash.now[:alert] = "Failed to update user"
        format.html { render partial: 'admin/manage_users_role_form', user: @user, open: true, layout: false }
        format.turbo_stream
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:role, scopes: [])
  end
end
