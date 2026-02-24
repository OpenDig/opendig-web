class AdminController < ApplicationController
  before_action :require_admin
  def manage_users
    @users = User.all
  end

  def update_user
    @user = User.find(params[:user][:id])
    
    respond_to do |format|
      format.turbo_stream do
        _success = @user.update(user_params)
        render turbo_stream: turbo_stream.replace(@user, partial: 'admin/manage_users_row', locals: { user: @user })
      end
    end
  end
end
