module Api
  module V1
    class DevicesController < Api::BaseController
      before_action :authenticate_device!, only: [:destroy]

      # POST /api/v1/devices/pair  { code, device_name? }
      # Unauthenticated: redeems a pairing code, creates a device, and returns the
      # device's token plus the full configuration bundle.
      def pair
        code = PairingCode.redeem(params[:code])
        return render json: { error: 'invalid_or_expired_code' }, status: :unauthorized if code.nil?

        user = code.user
        return render json: { error: 'user_not_found' }, status: :unprocessable_entity if user.nil?

        device, token = Device.create_for(user, device_name: params[:device_name] || code.device_name)

        render json: {
          token: token,
          device: { id: device.device_id, name: device.device_name },
          config: DeviceConfiguration.new(user).as_json
        }, status: :created
      end

      # DELETE /api/v1/devices/current  (Bearer) -- the device revokes itself.
      def destroy
        @current_device.revoke!
        head :no_content
      end
    end
  end
end
