Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  get '/login', to: 'sessions#login', as: :login
  direct(:auth) { |provider| "/auth/#{provider}" } # As per OmniAuth documentation
  get '/auth/:provider/callback', to: 'sessions#create', as: :auth_callback
  get '/auth/failure', to: 'sessions#failure', as: :auth_failure
  delete '/logout', to: 'sessions#destroy', as: :logout

  resources :areas, only: %i[index new create] do
    resources :squares, only: %i[index new create] do
      resources :pails, only: [:index]
      resources :finds, only: [:index]
      resources :loci, only: %i[index show edit new create update]
    end
  end

  resources :registrar
  resources :bulk_uploads, only: %i[new create]

  resources :admin, only: [] do
    collection do
      get 'manage_users'
    end
  end

  resources :reports, only: %i[index show]

  root to: 'areas#index'
end
