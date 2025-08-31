class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :dispatch_user, if: :user_signed_in?

  # ✅ chama o armazenamento da última página navegável
  before_action :store_user_location!, if: :storable_location?
  # 🔑 novo: captura return_to vindo na query mesmo em telas do Devise
  before_action :capture_return_to

  NON_PAGE_PATHS = [
    %r{\A/services/cities},          # JSON de cidades
    %r{\A/services/\d+/availability} # JSON de disponibilidade
  ].freeze


  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up,        keys: %i[role name])
    devise_parameter_sanitizer.permit(:account_update, keys: %i[name])
  end

  # Ordem de preferência:
  # 1) return_to explícito (session)  2) stored_location_for  3) fallback por papel
  def after_sign_in_path_for(resource)
    rt = sanitize_return_path(session.delete(:return_to))
    return rt if rt

    stored = sanitize_return_path(stored_location_for(resource))
    return stored if stored

    resource.respond_to?(:professional?) && resource.professional? ? dashboard_path : root_path
  end


  private

  # ----- armazenar última URL navegável -----
  def storable_location?
    request.get? && is_navigational_format? && !devise_controller? && !request.xhr?
  end

  def store_user_location!
    store_location_for(:user, request.fullpath)
  end

  def capture_return_to
    session[:return_to] = params[:return_to] if params[:return_to].present?
  end


  # ----- suas regras pós-login -----

  def storable_location?
    request.get? &&
      !devise_controller? &&
      (request.format.html? || request.format.turbo_stream?) &&
      !request.xhr? &&
      NON_PAGE_PATHS.none? { |re| re.match?(request.path) }
  end

  def store_user_location!
    store_location_for(:user, request.fullpath)
  end

  def capture_return_to
    session[:return_to] = params[:return_to] if params[:return_to].present?
  end

  def dispatch_user
    return unless request.get?
    return if devise_controller?

    if current_user.professional? && !current_user.profile_completed?
      target = edit_profile_path(current_user)
      redirect_to(target) and return unless request.path == target
    end

    if current_user.professional? && request.path == root_path
      redirect_to dashboard_path and return
    end
  end

  def sanitize_return_path(path)
    return unless path.present?
    return unless path.start_with?('/') # evita URLs externas
    return if NON_PAGE_PATHS.any? { |re| re.match?(path) }
    path
  end
end
