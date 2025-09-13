# config/routes.rb
Rails.application.routes.draw do
  # Usa controller customizado do Devise p/ registrations
  devise_for :users, controllers: { registrations: "users/registrations" }

  root to: "services#index"

  get "up" => "rails/health#show", as: :rails_health_check

  resources :services do
    collection do
      get :cities
      get :mine
    end
    member do
      get :availability,          defaults: { format: :json }
      get :availability_summary,  defaults: { format: :json }
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

  resource :role, only: :update

  get "login_and_return", to: "pages#login_and_return", as: :login_and_return
  get "history",          to: "schedules#history",     as: :service_history

  # ---------------- Perfil profissional ----------------
  scope "users/:user_id" do
    get   "profile",      to: "professionals#edit",   as: nil
    get   "profile/edit", to: "professionals#edit",   as: :edit_profile
    patch "profile",      to: "professionals#update", as: :profile
  end

end
