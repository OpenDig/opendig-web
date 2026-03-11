Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  resources :loci, only: [] do
    collection do
      get :search
    end
  end

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
