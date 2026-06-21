Rails.application.routes.draw do
  get '/about', to: 'static_pages#about', as: 'about'
  get '/help', to: 'static_pages#help', as: 'help'

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  resources :loci, only: [] do
    collection do
      get :search
    end
  end
  get '/login', to: 'sessions#login', as: :login
  post '/login', to: 'sessions#password_login' # email/password sign-in
  get '/signup', to: 'registrations#new', as: :signup
  post '/signup', to: 'registrations#create'
  direct(:auth) { |provider| "/auth/#{provider}" } # As per OmniAuth documentation
  get '/auth/:provider/callback', to: 'sessions#create', as: :auth_callback
  get '/auth/failure', to: 'sessions#failure', as: :auth_failure
  delete '/logout', to: 'sessions#destroy', as: :logout

  resources :areas, only: %i[index new create] do
    collection do
      post :favorite_toggle
    end

    resources :squares, only: %i[index new create] do
      collection do
        post :favorite_toggle
      end
      resources :pails, only: [:index]
      resources :finds, only: [:index]
      resources :loci, only: %i[index show edit new create update]
    end
  end

  resources :registrar
  resources :bulk_uploads, only: %i[new create]

  # Bulk locus-photo association (parse convention-named photos -> suggest loci).
  get  '/photos',           to: 'photos#review',    as: :photos_review
  post '/photos/associate', to: 'photos#associate', as: :photo_associate

  # Superuser project administration (runs at the apex host, no subdomain).
  resources :projects, only: %i[index new create edit update]

  patch '/admin/update_user/:id', to: 'admin#update_user', as: :admin_update_user
  resources :admin, only: [] do
    collection do
      get 'manage_users', as: :manage_users
    end
  end

  resources :invitations, only: %i[create]
  delete '/invitations', to: 'invitations#destroy', as: :revoke_invitation

  # User account (holds the low-frequency device-pairing section)
  get    '/account',               to: 'account#show',               as: :account
  post   '/account/pairing_code',  to: 'account#create_pairing_code', as: :account_pairing_code
  get    '/account/pairing_status', to: 'account#pairing_status',     as: :account_pairing_status
  delete '/account/devices/:id',   to: 'account#revoke_device',       as: :account_device

  # Token-authenticated device API (no project subdomain)
  namespace :api do
    namespace :v1 do
      post   'devices/pair',    to: 'devices#pair'
      delete 'devices/current', to: 'devices#destroy'
      get    'config',          to: 'config#show'
      get    'photos/pending',  to: 'photos#pending'
    end
  end

  resources :reports, only: %i[index show]

  root to: 'areas#index'
end
