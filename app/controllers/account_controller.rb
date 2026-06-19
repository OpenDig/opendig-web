class AccountController < ApplicationController
  before_action :require_authentication

  def show
    @devices = Device.for_user(current_user.id_as_string)
  end

  # Generate a short-lived pairing code for the current user to enter on a device.
  def create_pairing_code
    @pairing_code = PairingCode.generate_for(current_user, device_name: params[:device_name])
    @devices = Device.for_user(current_user.id_as_string)
    render :show
  end

  # Polled by the account page to close the "did it work?" loop: a pending code
  # is deleted when redeemed, so "not found" (within its lifetime) means claimed.
  def pairing_status
    code = PairingCode.find(params[:code])
    if code.nil?
      newest = Device.for_user(current_user.id_as_string).max_by { |device| device.created_at.to_s }
      render json: { status: 'claimed', device_name: newest&.device_name }
    elsif code.active?
      render json: { status: 'pending' }
    else
      render json: { status: 'expired' }
    end
  end

  def revoke_device
    device = Device.find(params[:id])
    if device && device.user_id == current_user.id_as_string
      device.revoke!
      flash[:notice] = 'Device revoked.'
    else
      flash[:alert] = 'Device not found.'
    end
    redirect_to account_path
  end
end
