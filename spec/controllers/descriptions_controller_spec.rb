require 'rails_helper'

RSpec.describe DescriptionsController, type: :controller do
  let(:users) { load_user_fixtures }

  before do
    allow(controller).to receive(:set_db)
    # check_editing_mode is the app-wide EDITING_ENABLED gate (on in prod);
    # stub it so these tests isolate the descriptions authorization.
    allow(controller).to receive(:check_editing_mode)
    allow(ProjectDescriptions).to receive_messages(effective: { 'lookups' => { 'designation' => ['Bead'] }, 'description_types' => {} }, version: 0)
  end

  describe 'GET edit (dig-director gate)' do
    it 'allows a dig director' do
      session[:user_id] = users[:dig_director].id
      get :edit
      expect(response).to be_successful
    end

    it 'allows a superuser' do
      session[:user_id] = users[:superuser].id
      get :edit
      expect(response).to be_successful
    end

    it 'denies a registrar' do
      session[:user_id] = users[:registrar].id
      get :edit
      expect(response).to redirect_to(controller.root_path)
    end

    it 'denies a plain viewer' do
      session[:user_id] = users[:viewer].id
      get :edit
      expect(response).to redirect_to(controller.root_path)
    end
  end

  describe 'PATCH update' do
    before { session[:user_id] = users[:dig_director].id }

    it 'saves edited lookup lists (one value per line)' do
      allow(ProjectDescriptions).to receive(:override).and_return({})
      captured = nil
      allow(ProjectDescriptions).to receive(:save) { |_project, override| captured = override }

      patch :update, params: { mode: 'lookups', lookups: { 'designation' => "Bead\nMilestone\n" } }

      expect(captured['lookups']['designation']).to eq(%w[Bead Milestone])
      expect(response).to redirect_to(edit_descriptions_path)
    end

    it 'saves valid raw JSON' do
      expect(ProjectDescriptions).to receive(:save)
      patch :update, params: { mode: 'raw', raw_json: '{"lookups":{},"description_types":{}}' }
      expect(response).to redirect_to(edit_descriptions_path)
    end

    it 'rejects malformed JSON' do
      expect(ProjectDescriptions).not_to receive(:save)
      patch :update, params: { mode: 'raw', raw_json: '{ not valid' }
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects JSON missing required keys' do
      expect(ProjectDescriptions).not_to receive(:save)
      patch :update, params: { mode: 'raw', raw_json: '{"foo":1}' }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE destroy' do
    it 'resets the project to the defaults' do
      session[:user_id] = users[:dig_director].id
      expect(ProjectDescriptions).to receive(:reset)
      delete :destroy
      expect(response).to redirect_to(edit_descriptions_path)
    end
  end
end
