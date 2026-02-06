Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  resources :areas, only: %i[index new create] do
    resources :squares, only: %i[index new create] do
      resources :pails, only: [:index]
      resources :finds, only: [:index]
      resources :loci, only: %i[index show edit new create update]
    end
  end

  resources :registrar
  resources :bulk_uploads, only: %i[new create]

  resources :reports, only: %i[index show]

  root to: 'areas#index'
end
