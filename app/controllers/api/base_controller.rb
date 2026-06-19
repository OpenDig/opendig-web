module Api
  # Base for the token-authenticated device API. Deliberately does NOT inherit the
  # web ApplicationController, so it skips subdomain/project resolution, session
  # handling, and the production HTTP-basic gate. Authentication is via an opaque
  # bearer token that maps to a Device record.
  class BaseController < ActionController::API
    private

    def authenticate_device!
      @current_device = Device.authenticate(bearer_token)
      return render_unauthorized if @current_device.nil?

      @current_user = @current_device.user
      render_unauthorized if @current_user.nil?
    end

    def bearer_token
      request.authorization.to_s[/\ABearer (.+)\z/, 1]
    end

    def render_unauthorized
      render json: { error: 'unauthorized' }, status: :unauthorized
    end
  end
end
