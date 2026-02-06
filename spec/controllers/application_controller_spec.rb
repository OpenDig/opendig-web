require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  # Create a test controller to test ApplicationController functionality
  controller do
    def index
      render plain: 'index'
    end

    def new
      render plain: 'new'
    end

    def create
      render plain: 'create'
    end

    def edit
      render plain: 'edit'
    end

    def update
      render plain: 'update'
    end

    def destroy
      render plain: 'destroy'
    end
  end

  let(:mock_db) { instance_double(CouchRest::Database) }
  let(:mock_descriptions) { { 'pottery' => 'Ceramic vessels' } }

  before do
    allow(Rails.application.config).to receive(:couchdb).and_return(mock_db)
    allow(Rails.application.config).to receive(:descriptions).and_return(mock_descriptions)
  end

  describe 'before_action callbacks' do
    describe 'set_db' do
      it 'sets @db from Rails configuration' do
        get :index

        expect(assigns(:db)).to eq(mock_db)
      end
    end

    describe 'set_descriptions' do
      it 'sets @descriptions from Rails configuration' do
        get :index

        expect(assigns(:descriptions)).to eq(mock_descriptions)
      end
    end

    describe 'set_edit_mode' do
      context 'when EDITING_ENABLED is set' do
        it 'sets @editing_enabled to the ENV value' do
          allow(ENV).to receive(:[]).with('EDITING_ENABLED').and_return('true')

          get :index

          expect(assigns(:editing_enabled)).to eq('true')
        end
      end

      context 'when EDITING_ENABLED is not set' do
        it 'sets @editing_enabled to false' do
          allow(ENV).to receive(:[]).with('EDITING_ENABLED').and_return(nil)

          get :index

          expect(assigns(:editing_enabled)).to eq(false)
        end
      end
    end

    describe 'check_editing_mode' do
      before do
        routes.draw do
          get 'index' => 'anonymous#index'
          get 'new' => 'anonymous#new'
          post 'create' => 'anonymous#create'
          get 'edit' => 'anonymous#edit'
          patch 'update' => 'anonymous#update'
          delete 'destroy' => 'anonymous#destroy'
        end
      end

      context 'when editing is enabled' do
        before do
          allow(ENV).to receive(:[]).with('EDITING_ENABLED').and_return('true')
        end

        it 'allows access to new action' do
          get :new
          expect(response).to be_successful
        end

        it 'allows access to create action' do
          post :create
          expect(response).to be_successful
        end

        it 'allows access to edit action' do
          get :edit
          expect(response).to be_successful
        end

        it 'allows access to update action' do
          patch :update
          expect(response).to be_successful
        end

        it 'allows access to destroy action' do
          delete :destroy
          expect(response).to be_successful
        end
      end

      context 'when editing is disabled' do
        before do
          allow(ENV).to receive(:[]).with('EDITING_ENABLED').and_return(nil)
          request.env['HTTP_REFERER'] = '/previous_page'
        end

        it 'redirects from new action with error flash' do
          get :new

          expect(flash[:error]).to eq('Editing is disabled')
          expect(response).to redirect_to('/previous_page')
        end

        it 'redirects from create action with error flash' do
          post :create

          expect(flash[:error]).to eq('Editing is disabled')
          expect(response).to redirect_to('/previous_page')
        end

        it 'redirects from edit action with error flash' do
          get :edit

          expect(flash[:error]).to eq('Editing is disabled')
          expect(response).to redirect_to('/previous_page')
        end

        it 'redirects from update action with error flash' do
          patch :update

          expect(flash[:error]).to eq('Editing is disabled')
          expect(response).to redirect_to('/previous_page')
        end

        it 'redirects from destroy action with error flash' do
          delete :destroy

          expect(flash[:error]).to eq('Editing is disabled')
          expect(response).to redirect_to('/previous_page')
        end

        it 'allows access to index action (not restricted)' do
          get :index

          expect(response).to be_successful
          expect(flash[:error]).to be_nil
        end
      end
    end
  end

  describe 'sanity check spec' do
    it 'has all the documents' do
      # Temporarily remove the mock to access the real database
      allow(Rails.application.config).to receive(:couchdb).and_call_original

      # five docs, plus the design doc and config doc
      expect(Rails.application.config.couchdb.all_docs['rows'].count).to eq(7)
    end
  end
end
