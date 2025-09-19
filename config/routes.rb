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

  resource :role, only: :update, controller: "roles"

  get "login_and_return", to: "pages#login_and_return", as: :login_and_return
  get "history",          to: "schedules#history",     as: :service_history

  # ---------------- Perfil profissional ----------------
  scope "users/:user_id" do
    get   "profile",      to: "professionals#edit",   as: nil
    get   "profile/edit", to: "professionals#edit",   as: :edit_profile
    patch "profile",      to: "professionals#update", as: :profile
  end

  # Páginas de erro (via exceptions_app)
  # match "/404", to: "errors#not_found",      via: :all
  # match "/422", to: "errors#unprocessable",  via: :all
  # match "/500", to: "errors#internal_error", via: :all
  # match "/403", to: "errors#forbidden",      via: :all

  # (Opcional DEV) rota que força 500 real p/ teste
  get "/dev/force_500", to: "errors#force_error" if Rails.env.development?

  # ✅ Catch-all: qualquer rota não mapeada cai na 404 customizada
  # match "*unmatched", to: "errors#not_found", via: :all

end
