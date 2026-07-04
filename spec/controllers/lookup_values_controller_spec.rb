require 'rails_helper'

RSpec.describe LookupValuesController, type: :controller do
  let(:users) { load_user_fixtures }

  before do
    allow(controller).to receive(:set_db)
    allow(controller).to receive(:check_editing_mode)
    allow(ProjectDescriptions).to receive(:lookup_list).and_return(%w[Painted Incised Trailed])
  end

  describe 'POST create' do
    it 'lets a registrar add a value to an allowlisted lookup and returns the list' do
      session[:user_id] = users[:registrar].id
      expect(ProjectDescriptions).to receive(:add_lookup_value).with(anything, 'decoration', 'Trailed')

      post :create, params: { lookup: 'decoration', value: 'Trailed' }, format: :json

      expect(response).to be_successful
      expect(response.parsed_body['values']).to eq(%w[Painted Incised Trailed])
    end

    it 'allows the custom_colors lookup' do
      session[:user_id] = users[:registrar].id
      expect(ProjectDescriptions).to receive(:add_lookup_value).with(anything, 'custom_colors', 'Iridescent')

      post :create, params: { lookup: 'custom_colors', value: 'Iridescent' }, format: :json
      expect(response).to be_successful
    end

    it 'refuses a lookup that is not on the allowlist' do
      session[:user_id] = users[:registrar].id
      expect(ProjectDescriptions).not_to receive(:add_lookup_value)

      post :create, params: { lookup: 'material', value: 'Unobtainium' }, format: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'denies a read-only viewer' do
      session[:user_id] = users[:viewer].id
      expect(ProjectDescriptions).not_to receive(:add_lookup_value)

      post :create, params: { lookup: 'decoration', value: 'Trailed' }, format: :json
      expect(response).not_to be_successful
    end
  end

  describe 'DELETE destroy' do
    it 'lets a registrar delete a value from an allowlisted lookup' do
      session[:user_id] = users[:registrar].id
      expect(ProjectDescriptions).to receive(:remove_lookup_value).with(anything, 'decoration', 'Incised')

      delete :destroy, params: { lookup: 'decoration', value: 'Incised' }, format: :json
      expect(response).to be_successful
    end

    it 'refuses a non-allowlisted lookup' do
      session[:user_id] = users[:registrar].id
      expect(ProjectDescriptions).not_to receive(:remove_lookup_value)

      delete :destroy, params: { lookup: 'material', value: 'Bronze' }, format: :json
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
