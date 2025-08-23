Rails.application.routes.draw do
  devise_for :users
  root to: "services#index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  get "dashboard", to: "dashboards#show"

  scope "users/:user_id" do
    get   "profile/edit", to: "professionals#edit",   as: :edit_profile
    patch "profile",      to: "professionals#update", as: :profile
  end
end
