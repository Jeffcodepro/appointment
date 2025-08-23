class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :dispatch_user, if: :user_signed_in?

  protected

  # Devise: signup mínimo
  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up,        keys: %i[role name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[name])
  end

  # Pós-login: deixa o dispatch decidir
  def after_sign_in_path_for(_resource)
    root_path
  end

  private

  # Redireciona conforme papel/estado do perfil
  def dispatch_user
    return unless request.get?
    return if devise_controller? # evita loop em /users/sign_in, /users/sign_up etc.

    # Profissional sem perfil completo → completar perfil
    if current_user.professional? && !current_user.profile_completed?
      target = edit_profile_path(current_user) # /users/:user_id/profile/edit
      redirect_to(target) and return unless request.path == target
    end

    # Profissional com perfil completo → se cair na home, vai pro dashboard
    if current_user.professional? && request.path == root_path
      redirect_to dashboard_path and return
    end

    # Cliente: permanece na home (root) ou na página que acessou
  end
end
