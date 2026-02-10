require 'rails_helper'

RSpec.describe "Admins", type: :request do
  describe "GET /manage_users" do
    it "returns http success" do
      get "/admin/manage_users"
      expect(response).to have_http_status(:success)
    end
  end

end
