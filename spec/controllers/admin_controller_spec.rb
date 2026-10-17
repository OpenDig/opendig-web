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

  describe 'GET manage_users (rendered)' do
    render_views

    before do
      session[:user_id] = users[:dig_director].id
      # role_scopes_for stubbed to avoid the areas/squares views
      allow(User).to receive_messages(find_all: [users[:dig_director], users[:viewer]], role_scopes_for: {})
      allow(Invitation).to receive(:for_project).and_return([])
    end

    it 'renders the members table and invite form' do
      get :manage_users
      expect(response).to be_successful
      expect(response.body).to include('User Management')
      expect(response.body).to include('Invite a user')
      expect(response.body).to include('Members')
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

  describe 'PATCH update_user with an email account id' do
    it 'routes ids ending in a domain to the whole id, not a format' do
      expect(patch: '/admin/update_user/email__swat@lasierra.edu')
        .to route_to('admin#update_user', id: 'email__swat@lasierra.edu')
    end

    it 'returns 404 for an unknown user' do
      session[:user_id] = users[:dig_director].id

      patch :update_user, params: { id: 'email__nobody@example.com', user: { role: 'registrar' } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE destroy_users' do
    let(:spammer) { User.register(email: 'spam@example.com', password: 'supersecret', name: 'Spam') }

    before { spammer.save }

    after { User.for_email('spam@example.com')&.destroy! }

    it 'lets a superuser delete selected accounts' do
      session[:user_id] = users[:superuser].id

      delete :destroy_users, params: { user_ids: [spammer.id_as_string] }

      expect(User.for_email('spam@example.com')).to be_nil
      expect(flash[:notice]).to eq('Deleted 1 user')
      expect(response).to redirect_to(controller.manage_users_admin_index_path)
    end

    it 'never deletes the current user or another superuser' do
      session[:user_id] = users[:superuser].id
      other_superuser = users[:superuser].dup
      allow(User).to receive(:find).and_call_original
      allow(User).to receive(:find).with('test__other').and_return(other_superuser)
      expect(other_superuser).not_to receive(:destroy!)

      delete :destroy_users, params: { user_ids: [users[:superuser].id_as_string, 'test__other'] }

      expect(flash[:notice]).to eq('Deleted 0 users')
    end

    it 'forbids a dig director' do
      session[:user_id] = users[:dig_director].id

      delete :destroy_users, params: { user_ids: [spammer.id_as_string] }

      expect(User.for_email('spam@example.com')).to be_present
      expect(response).to redirect_to(controller.root_path)
    end
  end

  describe 'GET manage_users delete controls' do
    render_views

    before do
      allow(User).to receive_messages(find_all: [users[:superuser], users[:viewer]], role_scopes_for: {})
      allow(Invitation).to receive(:for_project).and_return([])
    end

    it 'shows checkboxes to a superuser, except on their own row' do
      session[:user_id] = users[:superuser].id
      get :manage_users

      expect(response.body).to include('Delete selected', %(value="#{users[:viewer].id_as_string}"))
      expect(response.body).not_to include(%(value="#{users[:superuser].id_as_string}" form="delete_users_form"))
    end

    it 'hides them from a dig director' do
      allow(User).to receive(:find_all).and_return([users[:dig_director], users[:viewer]])
      session[:user_id] = users[:dig_director].id
      get :manage_users

      expect(response.body).not_to include('Delete selected')
    end
  end
end
