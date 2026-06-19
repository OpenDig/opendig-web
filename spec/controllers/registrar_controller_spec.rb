require 'rails_helper'

RSpec.describe RegistrarController, type: :controller do
  let(:users) { load_user_fixtures }
  let(:db) { instance_double(CouchRest::Database) }

  before do
    allow(controller).to receive(:set_db)
    controller.instance_variable_set(:@db, db)
    allow(db).to receive(:view).with('opendig/seasons', { group: true }).and_return({ 'rows' => [{ 'key' => 2020 }] })
    allow(Registrar).to receive(:all_by_season).and_return([])
  end

  describe 'GET index (read access)' do
    it 'allows a read-only area supervisor' do
      session[:user_id] = users[:area_supervisor].id
      get :index
      expect(response).to be_successful
    end

    it 'allows a registrar' do
      session[:user_id] = users[:registrar].id
      get :index
      expect(response).to be_successful
    end

    it 'redirects a plain viewer (no registrar access)' do
      session[:user_id] = users[:viewer].id
      get :index
      expect(response).to redirect_to(controller.root_path)
    end
  end

  describe 'GET edit (write access)' do
    let(:params) { { id: 'doc1', pail_id: '1', item_number: '1', item_locus_code: '1.1.001' } }

    it 'redirects a read-only area supervisor before loading the item' do
      session[:user_id] = users[:area_supervisor].id
      get :edit, params: params
      expect(response).to redirect_to(controller.root_path)
    end

    it 'redirects a square supervisor' do
      session[:user_id] = users[:square_supervisor].id
      get :edit, params: params
      expect(response).to redirect_to(controller.root_path)
    end
  end
end
