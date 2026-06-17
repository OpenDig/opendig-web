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

  patch '/admin/update_user/:id', to: 'admin#update_user', as: :admin_update_user
  resources :admin, only: [] do
    collection do
      get 'manage_users', as: :manage_users
    end
  end

  resources :reports, only: %i[index show]

  resources :users, only: [:show, :edit, :create, :update, :destroy]

  root to: 'areas#index'
end
