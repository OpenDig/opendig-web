class UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy]
  before_action :require_admin

  # GET /users/1 or /users/1.json
  def show; end

  # GET /users/new
  # def new; end

  # GET /users/1/edit
  def edit; end

  # POST /users or /users.json
  #
  # This action generates an invitation rather than a user.
  # User is created when the invitee accepts the invitation.
  # TODO: implementation
  def create
    # @user = User.new(user_params)

    respond_to do |format|
      # if @user.save
      if false
        format.html { redirect_to user_url(@user), notice: 'User was successfully created.' }
        format.json { render :show, status: :created, location: @user }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /users/1 or /users/1.json
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to user_url(@user), notice: 'User was successfully updated.' }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1 or /users/1.json
  def destroy
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url, notice: 'User was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.fetch(:user, {})
  end
end
