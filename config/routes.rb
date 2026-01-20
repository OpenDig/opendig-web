Rails.application.routes.draw do
  get '/about', to: 'static_pages#about', as: 'about'
  get '/help', to: 'static_pages#help', as: 'help'

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  resources :areas, only: [:index, :new, :create] do
    resources :squares, only: [:index, :new, :create] do
      resources :pails, only: [:index]
      resources :finds, only: [:index]
      resources :loci, only: [:index, :show, :edit, :new, :create, :update]
    end
  end

  resources :registrar
  resources :bulk_uploads, only: [:new, :create]

  resources :reports, only: [:index, :show]

  root to: 'areas#index'
end
