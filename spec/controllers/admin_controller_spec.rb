require 'rails_helper'

RSpec.describe AdminController, type: :controller do
  let(:users) { load_user_fixtures }

  describe 'GET manage_users' do
    before { allow(User).to receive(:find_all).and_return([]) }

    it 'allows a dig director' do
      session[:user_id] = users[:dig_director].id
      get :manage_users
      expect(response).to be_successful
    end

    it 'allows a superuser' do
      session[:user_id] = users[:superuser].id
      get :manage_users
      expect(response).to be_successful
    end

    it 'redirects a registrar (cannot manage roles)' do
      session[:user_id] = users[:registrar].id
      get :manage_users
      expect(response).to redirect_to(controller.root_path)
    end
  end

  describe 'PATCH update_user' do
    let(:target) { users[:viewer] }

    before do
      # current_user lookups use the real fixtures; only the edited user is stubbed.
      allow(User).to receive(:find).and_call_original
      allow(User).to receive(:find).with(target.id_as_string).and_return(target)
    end

    it 'lets a dig director assign a non-superuser role, scoped to the project' do
      session[:user_id] = users[:dig_director].id
      expect(target).to receive(:current_dig=).with('opendig')
      expect(target).to receive(:update).and_return(true)

      patch :update_user, params: { id: target.id_as_string, user: { role: 'registrar' } }
    end

    it 'blocks a dig director from assigning superuser' do
      session[:user_id] = users[:dig_director].id
      allow(target).to receive(:current_dig=)
      expect(target).not_to receive(:update)

      patch :update_user, params: { id: target.id_as_string, user: { role: 'superuser' } }

      expect(flash[:alert]).to match(/not allowed/i)
    end

    it 'lets a superuser assign superuser' do
      session[:user_id] = users[:superuser].id
      allow(target).to receive(:current_dig=)
      expect(target).to receive(:update).and_return(true)

      patch :update_user, params: { id: target.id_as_string, user: { role: 'superuser' } }
    end
  end
end
