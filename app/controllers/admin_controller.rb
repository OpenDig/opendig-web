class AdminController < ApplicationController
  def manage_users
    @users = User.all
  end
end
