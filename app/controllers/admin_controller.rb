class AdminController < ApplicationController
  before_action :require_admin
  def manage_users
    @users = User.all
  end
end
