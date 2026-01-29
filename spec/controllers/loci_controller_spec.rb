require 'rails_helper'

RSpec.describe LociController, type: :controller do
  let(:db) { instance_double(CouchRest::Database) }
  let(:area_id) { '24' }
  let(:square_id) { 'A' }
  let(:locus_code) { '001' }
  let(:locus_data) do
    {
      'area' => area_id,
      'square' => square_id,
      'code' => locus_code,
      '_id' => 'locus_123',
      'locus_type' => 'context',
      'designation' => 'test designation',
      'age' => 'modern'
    }
  end

  before do
    allow(controller).to receive(:set_db)
    allow(controller).to receive(:set_descriptions)
    allow(controller).to receive(:set_edit_mode)
    allow(controller).to receive(:check_editing_mode)
    controller.instance_variable_set(:@db, db)
    controller.instance_variable_set(:@editing_enabled, true)
  end

  describe 'GET index' do
    let(:loci_rows) do
      [
        { 'key' => [area_id, square_id, '001', 'locus_1', 'context', 'designation 1', 'modern'] },
        { 'key' => [area_id, square_id, '002', 'locus_2', 'feature', 'designation 2', 'ancient'] }
      ]
    end

    before do
      allow(db).to receive(:view).with('opendig/loci',
                                       { group: true, start_key: [area_id, square_id],
                                         end_key: [area_id, square_id, {}] })
                                 .and_return({ 'rows' => loci_rows })
    end

    it 'sets @area, @square, and @loci' do
      get :index, params: { area_id: area_id, square_id: square_id }

      expect(assigns(:area)).to eq(area_id)
      expect(assigns(:square)).to eq(square_id)
      expect(assigns(:loci)).to be_an(Array)
      expect(assigns(:loci).size).to eq(2)
      expect(assigns(:loci).first).to be_a(Locus)
      expect(assigns(:loci).first.code).to eq('001')
      expect(response).to be_successful
    end
  end

  describe 'GET show' do
    before do
      allow(db).to receive(:view).with('opendig/locus', key: [area_id, square_id, locus_code])
                                 .and_return({ 'rows' => [{ 'value' => locus_data }] })
    end

    it 'sets @area, @square, @locus_code, and @locus' do
      get :show, params: { area_id: area_id, square_id: square_id, id: locus_code }

      expect(assigns(:area)).to eq(area_id)
      expect(assigns(:square)).to eq(square_id)
      expect(assigns(:locus_code)).to eq(locus_code)
      expect(assigns(:locus)).to eq(locus_data)
      expect(response).to be_successful
    end

    context 'when locus is not found' do
      before do
        allow(db).to receive(:view).with('opendig/locus', key: [area_id, square_id, locus_code])
                                   .and_return({ 'rows' => [] })
      end

      it 'sets @locus to nil' do
        get :show, params: { area_id: area_id, square_id: square_id, id: locus_code }

        expect(assigns(:locus)).to be_nil
      end
    end
  end

  describe 'GET new' do
    it 'sets @area, @square, and initializes @locus with locus_type' do
      get :new, params: { area_id: area_id, square_id: square_id, type: 'context' }

      expect(assigns(:area)).to eq(area_id)
      expect(assigns(:square)).to eq(square_id)
      expect(assigns(:locus)).to eq({ 'locus_type' => 'context' })
      expect(response).to be_successful
    end

    it 'works without a type parameter' do
      get :new, params: { area_id: area_id, square_id: square_id }

      expect(assigns(:locus)).to eq({ 'locus_type' => nil })
    end
  end

  describe 'GET edit' do
    before do
      allow(db).to receive(:view).with('opendig/locus', key: [area_id, square_id, locus_code])
                                 .and_return({ 'rows' => [{ 'value' => locus_data }] })
    end

    it 'sets @area, @square, @locus_code, and @locus' do
      get :edit, params: { area_id: area_id, square_id: square_id, id: locus_code }

      expect(assigns(:area)).to eq(area_id)
      expect(assigns(:square)).to eq(square_id)
      expect(assigns(:locus_code)).to eq(locus_code)
      expect(assigns(:locus)).to eq(locus_data)
      expect(response).to be_successful
    end
  end

  describe 'POST create' do
    let(:new_locus_params) do
      {
        'area' => area_id,
        'square' => square_id,
        'code' => '003',
        'locus_type' => 'feature',
        'designation' => 'new test'
      }
    end

    context 'when save is successful' do
      it 'saves the locus, sets success flash, and redirects to area_square_loci_path' do
        expect(db).to receive(:save_doc).with(new_locus_params).and_return(true)

        post :create, params: { area_id: area_id, square_id: square_id, locus: new_locus_params }

        expect(flash[:success]).to eq('Success! New Locus Created')
        expect(response).to redirect_to(area_square_loci_path(area_id, square_id))
      end
    end

    context 'when save fails' do
      it 'sets error flash and renders new template' do
        expect(db).to receive(:save_doc).with(new_locus_params).and_return(false)

        post :create, params: { area_id: area_id, square_id: square_id, locus: new_locus_params }

        expect(flash.now[:error]).to eq('Something went wrong')
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PUT/PATCH update' do
    let(:updated_params) do
      {
        'designation' => 'updated designation',
        'age' => 'medieval'
      }
    end

    before do
      allow(db).to receive(:view).with('opendig/locus', key: [area_id, square_id, locus_code])
                                 .and_return({ 'rows' => [{ 'value' => locus_data }] })
    end

    context 'when save is successful' do
      it 'merges params, saves the locus, sets success flash, and redirects' do
        expected_doc = locus_data.merge(updated_params)
        expect(db).to receive(:save_doc).with(expected_doc).and_return(true)

        patch :update, params: { area_id: area_id, square_id: square_id, id: locus_code, locus: updated_params }

        expect(flash[:success]).to eq('Success! Locus Updated')
        expect(response).to redirect_to(area_square_locus_path(area_id, square_id, locus_code))
      end
    end

    context 'when save fails' do
      it 'sets error flash and renders edit template' do
        expected_doc = locus_data.merge(updated_params)
        expect(db).to receive(:save_doc).with(expected_doc).and_return(false)

        patch :update, params: { area_id: area_id, square_id: square_id, id: locus_code, locus: updated_params }

        expect(flash.now[:error]).to eq('Something went wrong')
        expect(response).to render_template(:edit)
      end
    end

    context 'with nested array parameters' do
      let(:nested_params) do
        {
          'designation' => 'updated',
          'finds' => {
            '0' => { 'type' => 'pottery', 'count' => '5' },
            '1' => { 'type' => 'bone', 'count' => '3' }
          }
        }
      end

      it 'converts indexed hashes to arrays' do
        expected_finds = [
          { 'type' => 'pottery', 'count' => '5' },
          { 'type' => 'bone', 'count' => '3' }
        ]
        expected_doc = locus_data.merge('designation' => 'updated', 'finds' => expected_finds)

        expect(db).to receive(:save_doc).with(expected_doc).and_return(true)

        patch :update, params: { area_id: area_id, square_id: square_id, id: locus_code, locus: nested_params }

        expect(response).to redirect_to(area_square_locus_path(area_id, square_id, locus_code))
      end
    end
  end
end
