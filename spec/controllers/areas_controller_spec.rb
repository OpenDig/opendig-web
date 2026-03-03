require "rails_helper"

RSpec.describe AreasController, type: :controller do

  describe "GET index" do
    it "assigns @areas" do
      get :index
      expect(assigns(:areas).map{|a| a['key']}).to eq(["24", "25", "42", "55"])
    end
  end

  describe "POST create" do
    let(:db) { instance_double(CouchRest::Database) }
    let(:existing_areas) { [{"key" => "24"}, {"key" => "25"}, {"key" => "42"}, {"key" => "55"}] }

    before do
      allow(controller).to receive(:set_db)
      allow(controller).to receive(:set_descriptions)
      allow(controller).to receive(:set_edit_mode)
      allow(controller).to receive(:check_editing_mode)
      allow(controller).to receive(:require_editor)
      controller.instance_variable_set(:@db, db)
      controller.instance_variable_set(:@editing_enabled, true)
    end

    context "when creating a new area" do
      before do
        allow(db).to receive(:view).with('opendig/areas', {group: true})
          .and_return({'rows' => existing_areas})
      end

      context "and save is successful" do
        it "creates the area, sets success flash, and redirects to areas_path" do
          expect(db).to receive(:save_doc).with({"area": "98", "temp-doc": true}).and_return(true)

          post :create, params: {area: "98"}

          expect(flash[:success]).to eq("area 98 created!")
          expect(response).to redirect_to(areas_path)
        end
      end

      context "and save fails" do
        it "sets error flash and renders new template" do
          expect(db).to receive(:save_doc).with({"area": "99", "temp-doc": true}).and_return(false)

          post :create, params: {area: "99"}

          expect(flash.now[:error]).to eq("Something went wrong")
          expect(response).to render_template(:new)
        end
      end
    end

    context "when area already exists" do
      before do
        allow(db).to receive(:view).with('opendig/areas', {group: true})
          .and_return({'rows' => existing_areas})
      end

      it "sets error flash and renders new template" do
        post :create, params: {area: "24"}

        expect(flash.now[:error]).to eq("area 24 already exists!")
        expect(response).to render_template(:new)
      end

      it "does not attempt to save the document" do
        expect(db).not_to receive(:save_doc)

        post :create, params: {area: "24"}
      end
    end
  end

end