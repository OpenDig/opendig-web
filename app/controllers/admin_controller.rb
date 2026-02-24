class AdminController < ApplicationController
  before_action :require_admin
  def manage_users
    @users = User.all
  end

  def update_user
    @user = User.find(params[:id])
    
    if @user.update(user_params)
      respond_to do |format|
        format.html { render partial: 'admin/manage_users_role_dropdown', locals: { user: @user }, layout: false }
      end
    else
      head :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:role)
  end
end
