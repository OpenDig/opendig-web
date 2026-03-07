require 'rails_helper'

RSpec.describe LociController do
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

  describe 'before_action callbacks' do
    describe 'set_locus' do
      it 'loads the locus from the database' do
        allow(db).to receive(:view).with('opendig/locus', key: [area_id, square_id, locus_code])
                                   .and_return({ 'rows' => [{ 'value' => locus_data }] })

        get :show, params: { area_id: area_id, square_id: square_id, id: locus_code }

        expect(controller.instance_variable_get(:@area)).to eq(area_id)
        expect(controller.instance_variable_get(:@square)).to eq(square_id)
        expect(controller.instance_variable_get(:@locus_code)).to eq(locus_code)
        expect(controller.instance_variable_get(:@locus)).to eq(locus_data)
      end

      context 'when locus is not found' do
        it 'sets @locus to nil' do
          allow(db).to receive(:view).with('opendig/locus', key: [nil, nil, nil])
                                     .and_return({ 'rows' => [] })

          controller.send(:set_locus)

          expect(controller.instance_variable_get(:@locus)).to be_nil
        end
      end

      it 'is called before show, edit, and update actions' do
        controller.instance_variable_set(:@locus, {})
        allow(db).to receive(:save_doc).and_return(false)
        allow(controller).to receive(:set_locus)

        get :show, params: { area_id: area_id, square_id: square_id, id: locus_code }
        get :edit, params: { area_id: area_id, square_id: square_id, id: locus_code }
        patch :update, params: { area_id: area_id, square_id: square_id, id: locus_code, locus: locus_data }
        expect(controller).to have_received(:set_locus).exactly(3).times
      end

      it 'is not called before index, new, and create actions' do
        controller.instance_variable_set(:@locus, {})
        allow(db).to receive_messages(view: { 'rows' => [] }, save_doc: false)
        allow(controller).to receive(:set_locus)

        get :index, params: { area_id: area_id, square_id: square_id, id: locus_code }
        put :new, params: { area_id: area_id, square_id: square_id, id: locus_code }
        put :create, params: { area_id: area_id, square_id: square_id, id: locus_code }
        expect(controller).not_to have_received(:set_locus)
      end
    end
  end

  describe 'private helpers' do
    describe 'repair_nested_params' do
      it 'converts indexed hashes to arrays' do
        input = {
          'finds' => {
            '0' => { 'type' => 'pottery', 'count' => '5' },
            '1' => { 'type' => 'bone', 'count' => '3' }
          }
        }
        expected_output = {
          'finds' => [
            { 'type' => 'pottery', 'count' => '5' },
            { 'type' => 'bone', 'count' => '3' }
          ]
        }

        output = controller.send(:repair_nested_params, input)
        expect(output).to eq(expected_output)
      end

      it 'does not modify non-indexed hashes' do
        input = {
          'finds' => {
            'a' => { 'type' => 'pottery', 'count' => '5' },
            'b' => { 'type' => 'bone', 'count' => '3' }
          }
        }

        output = controller.send(:repair_nested_params, input)
        expect(output).to eq(input)
      end

      it 'does not modify empty hashes' do
        input = { 'finds' => {} }

        output = controller.send(:repair_nested_params, input)
        expect(output).to eq(input)
      end
    end
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
        allow(db).to receive(:save_doc).with(new_locus_params).and_return(true)

        post :create, params: { area_id: area_id, square_id: square_id, locus: new_locus_params }

        expect(flash[:success]).to eq('Success! New Locus Created')
        expect(response).to redirect_to(area_square_loci_path(area_id, square_id))
      end
    end

    context 'when save fails' do
      it 'sets error flash and renders new template' do
        allow(db).to receive(:save_doc).with(new_locus_params).and_return(false)

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
        allow(db).to receive(:save_doc).with(expected_doc).and_return(true)

        patch :update, params: { area_id: area_id, square_id: square_id, id: locus_code, locus: updated_params }

        expect(flash[:success]).to eq('Success! Locus Updated')
        expect(response).to redirect_to(area_square_locus_path(area_id, square_id, locus_code))
      end
    end

    context 'when save fails' do
      it 'sets error flash and renders edit template' do
        expected_doc = locus_data.merge(updated_params)
        allow(db).to receive(:save_doc).with(expected_doc).and_return(false)

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

        allow(db).to receive(:save_doc).with(expected_doc).and_return(true)

        patch :update, params: { area_id: area_id, square_id: square_id, id: locus_code, locus: nested_params }

        expect(response).to redirect_to(area_square_locus_path(area_id, square_id, locus_code))
      end
    end
  end
end
