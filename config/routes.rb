Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

  resources :areas, only: [:index, :new, :create] do
    resources :squares, only: [:index, :new, :create] do
      resources :pails, only: [:index]
      resources :loci, only: [:index, :show, :edit, :new, :create, :update]
    end
  end

  resources :registrar

  root to: 'areas#index'
end
