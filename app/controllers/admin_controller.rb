class AdminController < ApplicationController
  before_action :require_admin
  def manage_users
    @users = User.all
  end

  def update_user
    @user = User.find(params[:id])
    
    if @user.update(user_params)
      respond_to do |format|
        format.html { render partial: 'admin/manage_users_role_dropdown', locals: { user: @user, change: :success }, layout: false }
      end
    else
      respond_to do |format|
        format.html { render partial: 'admin/manage_users_role_dropdown', locals: { user: @user, change: :failure }, layout: false }
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:role)
  end
end
