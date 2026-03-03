require "rails_helper"

RSpec.describe SquaresController, type: :controller do
  let(:db) { instance_double(CouchRest::Database) }
  let(:area_id) { "24" }
  let(:existing_squares) { [{"key" => [area_id, "A"]}, {"key" => [area_id, "B"]}, {"key" => [area_id, "C"]}] }

  before do
    allow(controller).to receive(:set_db)
    allow(controller).to receive(:set_descriptions)
    allow(controller).to receive(:set_edit_mode)
    allow(controller).to receive(:check_editing_mode)
    controller.instance_variable_set(:@db, db)
    controller.instance_variable_set(:@editing_enabled, true)

    allow(db).to receive(:view).with('opendig/squares', {group: true, start_key: [area_id], end_key: [area_id, {}]})
      .and_return({"rows" => existing_squares})
  end

  describe "GET index" do
    it "sets @area and @squares" do
      get :index, params: {area_id: area_id}

      expect(assigns(:area)).to eq(area_id)
      expect(assigns(:squares)).to eq(["A", "B", "C"])
      expect(response).to be_successful
    end
  end

  describe "GET new" do
    before do
      allow(controller).to receive(:require_editor)
    end

    it "sets @area and @squares" do
      get :new, params: {area_id: area_id}

      expect(assigns(:area)).to eq(area_id)
      expect(assigns(:squares)).to eq(["A", "B", "C"])
      expect(response).to be_successful
    end
  end

  describe "POST create" do
    before do
      allow(controller).to receive(:require_editor)
    end

    context "when creating a new square" do
      context "and save is successful" do
        it "creates the square, sets success flash, and redirects to area_squares_path" do
          expect(db).to receive(:save_doc).with({"temp-doc" => true, "square" => "D", "area" => area_id}).and_return(true)

          post :create, params: {area_id: area_id, square: "d"}

          expect(flash[:success]).to eq("Square D in area #{area_id} created!")
          expect(response).to redirect_to(area_squares_path(area_id))
        end

        it "uppercases the square name" do
          expect(db).to receive(:save_doc).with({"temp-doc" => true, "square" => "Z", "area" => area_id}).and_return(true)

          post :create, params: {area_id: area_id, square: "z"}

          expect(flash[:success]).to eq("Square Z in area #{area_id} created!")
        end
      end

      context "and save fails" do
        it "sets error flash and renders new template" do
          expect(db).to receive(:save_doc).with({"temp-doc" => true, "square" => "D", "area" => area_id}).and_return(false)

          post :create, params: {area_id: area_id, square: "d"}

          expect(flash.now[:error]).to eq("Something went wrong")
          expect(response).to render_template(:new)
        end
      end
    end

    context "when square already exists" do
      it "sets error flash and renders new template" do
        post :create, params: {area_id: area_id, square: "a"}

        expect(flash.now[:error]).to eq("Square A in area #{area_id} already exists!")
        expect(response).to render_template(:new)
      end

      it "does not attempt to save the document" do
        expect(db).not_to receive(:save_doc)

        post :create, params: {area_id: area_id, square: "B"}
      end
    end
  end

end
