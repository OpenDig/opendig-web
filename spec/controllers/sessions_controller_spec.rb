require 'rails_helper'

RSpec.describe SessionsController, type: :controller do
  describe 'GET create' do
    it 'redirects to the root path after login' do
      get :create, params: { code: 'valid_code' }
      expect(response).to redirect_to(root_path)
    end
  end
end
