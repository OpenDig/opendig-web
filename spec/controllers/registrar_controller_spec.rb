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

  describe 'GET index season + pipeline' do
    let(:finds) do
      [
        Registrar.new(['1', '1', '001', '1', '1', nil, 'Ceramic', 'a', nil, 'i1']),                      # incoming
        Registrar.new(['1', '1', '002', '1', '2', nil, 'Ceramic', 'b', 'initial registration', 'i2']),   # initial
        Registrar.new(['1', '1', '003', '1', '3', nil, 'Ceramic', 'c', 'WIP', 'i3']) # pending
      ]
    end

    before do
      session[:user_id] = users[:registrar].id
      allow(Registrar).to receive(:all_by_season).and_return(finds)
    end

    it 'defaults to the current season and offers it among the options' do
      get :index
      expect(assigns(:selected_season)).to eq(Date.current.year)
      expect(assigns(:seasons)).to include(Date.current.year, 2020)
    end

    it 'honours the season param' do
      allow(Registrar).to receive(:all_by_season).with(2020).and_return(finds)
      get :index, params: { season: '2020' }
      expect(assigns(:selected_season)).to eq(2020)
    end

    it 'counts every stage and defaults to Incoming' do
      get :index
      expect(assigns(:selected_stage)).to eq('incoming')
      expect(assigns(:stage_counts)).to include('incoming' => 1, 'initial' => 1, 'pending' => 1, 'all' => 3)
      expect(assigns(:finds).map(&:id)).to eq(['i1'])
    end

    it 'filters by the requested stage' do
      get :index, params: { status: 'pending' }
      expect(assigns(:finds).map(&:id)).to eq(['i3'])
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
