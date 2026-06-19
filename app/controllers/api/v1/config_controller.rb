module Api
  module V1
    class ConfigController < Api::BaseController
      before_action :authenticate_device!

      # GET /api/v1/config  (Bearer) -- returns a fresh configuration bundle,
      # reflecting any changes to the user's roles/projects since pairing.
      def show
        @current_device.touch!
        render json: DeviceConfiguration.new(@current_user).as_json
      end
    end
  end
end
