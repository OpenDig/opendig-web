require 'rails_helper'

RSpec.describe PailsController, type: :controller do
  let(:db) { instance_double(CouchRest::Database) }
  let(:area_id) { '24' }
  let(:square_id) { 'A' }
  let(:pail_key) { "#{area_id}.#{square_id}" }

  before do
    allow(controller).to receive(:set_db)
    allow(controller).to receive(:set_descriptions)
    allow(controller).to receive(:set_edit_mode)
    allow(controller).to receive(:check_editing_mode)
    controller.instance_variable_set(:@db, db)
    controller.instance_variable_set(:@editing_enabled, true)
  end

  describe 'GET index' do
    let(:pails_data) do
      [
        { 'value' => %w[3 001 2024-01-15] },
        { 'value' => %w[1 001 2024-01-10] },
        { 'value' => %w[10 002 2024-01-20] },
        { 'value' => %w[2 001 2024-01-12] }
      ]
    end

    before do
      allow(db).to receive(:view).with('opendig/pails', { reduce: false, keys: [pail_key] })
                                 .and_return({ 'rows' => pails_data })
    end

    it 'sets @area, @square, and @pails' do
      get :index, params: { area_id: area_id, square_id: square_id }

      expect(assigns(:area)).to eq(area_id)
      expect(assigns(:square)).to eq(square_id)
      expect(assigns(:pails)).to be_an(Array)
      expect(assigns(:pails).size).to eq(4)
      expect(assigns(:pails).first).to be_a(Pail)
      expect(response).to be_successful
    end

    it 'sorts pails by pail_number in ascending order' do
      get :index, params: { area_id: area_id, square_id: square_id }

      pail_numbers = assigns(:pails).map(&:pail_number)
      expect(pail_numbers).to eq(%w[1 2 3 10])
    end

    it 'creates Pail objects from the database rows' do
      get :index, params: { area_id: area_id, square_id: square_id }

      first_pail = assigns(:pails).first
      expect(first_pail.pail_number).to eq('1')
      expect(first_pail.locus).to eq('001')
      expect(first_pail.pail_date).to eq('2024-01-10')
    end
  end
end
