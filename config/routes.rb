Rails.application.routes.draw do
  devise_for :users
  # root to: "pages#home"
  root to: "services#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"

  resources :services do
    collection do
      get :cities
    end

    member do
      get :availability, defaults: { format: :json }
      get :availability_summary, defaults: { format: :json }
      get :calendar
    end
  end

  resources :schedules, only: [:create, :show] do
    resources :messages, only: [:create]
    member do
      patch :cancel
      patch :reject
      patch :accept
    end
  end

  resources :conversations, only: [:index, :create, :show] do
    resources :messages, only: [:create], controller: "messages"
  end

  resource :dashboard, only: [:show] do
    get :day
  end

  get "login_and_return", to: "pages#login_and_return", as: :login_and_return
  get "history", to: "schedules#history", as: :service_history


  scope "users/:user_id" do
    get   "profile/edit", to: "professionals#edit",   as: :edit_profile
    patch "profile",      to: "professionals#update", as: :profile
  end
end
