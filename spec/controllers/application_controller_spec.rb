require "rails_helper"

RSpec.describe ApplicationController, type: :controller do
  fixtures :users

  # Create a test controller to test ApplicationController functionality
  controller do
    def index
      render plain: "index"
    end

    def new
      render plain: "new"
    end

    def create
      render plain: "create"
    end

    def edit
      render plain: "edit"
    end

    def update
      render plain: "update"
    end

    def destroy
      render plain: "destroy"
    end
  end

  let(:mock_db) { instance_double(CouchRest::Database) }
  let(:mock_descriptions) { {"pottery" => "Ceramic vessels"} }

  before do
    allow(Rails.application.config).to receive(:couchdb).and_return(mock_db)
    allow(Rails.application.config).to receive(:descriptions).and_return(mock_descriptions)
  end

  describe "before_action callbacks" do
    describe "set_db" do
      it "sets @db from Rails configuration" do
        get :index

        expect(assigns(:db)).to eq(mock_db)
      end
    end

    describe "set_descriptions" do
      it "sets @descriptions from Rails configuration" do
        get :index

        expect(assigns(:descriptions)).to eq(mock_descriptions)
      end
    end

    describe "set_edit_mode" do
      context "when EDITING_ENABLED is set" do
        it "sets @editing_enabled to the ENV value" do
          allow(ENV).to receive(:[]).with('EDITING_ENABLED').and_return('true')

          get :index

          expect(assigns(:editing_enabled)).to eq('true')
        end
      end

      context "when EDITING_ENABLED is not set" do
        it "sets @editing_enabled to false" do
          allow(ENV).to receive(:[]).with('EDITING_ENABLED').and_return(nil)

          get :index

          expect(assigns(:editing_enabled)).to eq(false)
        end
      end
    end

    describe "check_editing_mode" do
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

      context "when editing is enabled" do
        before do
          allow(ENV).to receive(:[]).with('EDITING_ENABLED').and_return('true')
        end

        it "allows access to new action" do
          get :new
          expect(response).to be_successful
        end

        it "allows access to create action" do
          post :create
          expect(response).to be_successful
        end

        it "allows access to edit action" do
          get :edit
          expect(response).to be_successful
        end

        it "allows access to update action" do
          patch :update
          expect(response).to be_successful
        end

        it "allows access to destroy action" do
          delete :destroy
          expect(response).to be_successful
        end
      end

      context "when editing is disabled" do
        before do
          allow(ENV).to receive(:[]).with('EDITING_ENABLED').and_return(nil)
          request.env['HTTP_REFERER'] = '/previous_page'
        end

        it "redirects from new action with error flash" do
          get :new

          expect(flash[:error]).to eq("Editing is disabled")
          expect(response).to redirect_to('/previous_page')
        end

        it "redirects from create action with error flash" do
          post :create

          expect(flash[:error]).to eq("Editing is disabled")
          expect(response).to redirect_to('/previous_page')
        end

        it "redirects from edit action with error flash" do
          get :edit

          expect(flash[:error]).to eq("Editing is disabled")
          expect(response).to redirect_to('/previous_page')
        end

        it "redirects from update action with error flash" do
          patch :update

          expect(flash[:error]).to eq("Editing is disabled")
          expect(response).to redirect_to('/previous_page')
        end

        it "redirects from destroy action with error flash" do
          delete :destroy

          expect(flash[:error]).to eq("Editing is disabled")
          expect(response).to redirect_to('/previous_page')
        end

        it "allows access to index action (not restricted)" do
          get :index

          expect(response).to be_successful
          expect(flash[:error]).to be_nil
        end
      end
    end

    describe "check_session_timeout" do
      before do
        routes.draw do
          get 'index' => 'anonymous#index'
        end
      end

      it "resets session and sets alert flash if session has expired" do
        past_time = 31.minutes.ago
        session[:last_seen] = past_time

        expect(session).to receive(:destroy)
        get :index
        expect(flash[:alert]).to eq("Your session has expired due to inactivity.")
      end

      it "does not reset session if session is still valid" do
        recent_time = 10.minutes.ago
        session[:last_seen] = recent_time

        expect(session).not_to receive(:destroy)
        get :index
        expect(flash[:alert]).to be_nil
      end
    end

    describe "update_session_timestamp" do
      before do
        routes.draw do
          get 'index' => 'anonymous#index'
        end
      end

      it "updates session[:last_seen] to current time" do
        travel_to Time.current do
          get :index

          expect(session[:last_seen]).to be_within(1.second).of(Time.current)
        end
      end
    end
  end

  describe "sanity check spec" do
    it "has all the documents" do
      # Temporarily remove the mock to access the real database
      allow(Rails.application.config).to receive(:couchdb).and_call_original

      # five docs, plus the design doc and config doc
      expect(Rails.application.config.couchdb.all_docs["rows"].count).to eq(7)
    end
  end

  describe "authentication and authorization helper" do
    describe "current_user" do
      it "returns nil if no user is logged in" do
        expect(controller.send :current_user).to be_nil
      end

      it "returns the current user if logged in" do
        session[:user_id] = users(:viewer).id
        expect(controller.send :current_user).to eq(users(:viewer))
      end
    end

    describe "user_signed_in?" do
      it "returns false if no user is logged in" do
        expect(controller.send :user_signed_in?).to be_falsey
      end

      it "returns true if a user is logged in" do
        session[:user_id] = users(:viewer).id
        expect(controller.send :user_signed_in?).to be_truthy
      end
    end

    describe "require_authentication" do
      controller do
        before_action :require_authentication, only: [:protected]

        def protected
          render plain: "protected"
        end
      end

      before do
        routes.draw do
          get 'protected' => 'anonymous#protected'
        end
      end

      it "redirects to root path with error flash if not authenticated" do
        get :protected

        expect(flash[:error]).to eq("You must be logged in to access this section")
        expect(response).to redirect_to(controller.root_path)
      end

      it "allows access if authenticated" do
        session[:user_id] = users(:viewer).id

        get :protected

        expect(response).to be_successful
        expect(response.body).to eq("protected")
      end
    end

    describe "require_role" do
      controller do
        before_action :require_admin, only: [:admin_only]
        before_action :require_editor, only: [:edit_only]

        def edit_only
          render plain: "edit only"
        end

        def admin_only
          render plain: "admin only"
        end
      end

      before do
        routes.draw do
          get 'admin_only' => 'anonymous#admin_only'
          get 'edit_only' => 'anonymous#edit_only'
        end
      end

      it "redirects to root path with error flash if not authenticated" do
        get :admin_only

        expect(flash[:error]).to eq("You must be logged in to access this section")
        expect(response).to redirect_to(controller.root_path)
      end

      it "redirects to root path with error flash if authenticated but insufficient role" do
        session[:user_id] = users(:viewer).id

        get :admin_only

        expect(flash[:error]).to eq("You must be a(n) admin to access this section")
        expect(response).to redirect_to(controller.root_path)
      end

      it "allows access if authenticated and has sufficient role" do
        session[:user_id] = users(:admin).id

        get :admin_only

        expect(response).to be_successful
        expect(response.body).to eq("admin only")
      end

      it "allows access to editor-only action for editor role" do
        session[:user_id] = users(:editor).id

        get :edit_only

        expect(response).to be_successful
        expect(response.body).to eq("edit only")
      end

      it "allows access to editor-only action for admin role" do
        session[:user_id] = users(:admin).id

        get :edit_only

        expect(response).to be_successful
        expect(response.body).to eq("edit only")
      end
    end
  end
end
