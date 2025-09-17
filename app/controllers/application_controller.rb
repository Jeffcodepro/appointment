# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  # ✅ Active Storage precisa disso para gerar URLs corretas (especialmente com Cloudinary)
  include ActiveStorage::SetCurrent
  before_action :set_active_storage_url_options

  before_action :authenticate_user!, unless: :devise_controller?
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :dispatch_user, if: :user_signed_in?

  before_action :store_user_location!, if: :storable_location?
  before_action :capture_return_to

  NON_PAGE_PATHS = [
    %r{\A/services/cities},
    %r{\A/services/\d+/availability}
  ].freeze

  protected

  def configure_permitted_parameters
    # Permite campos extras, inclusive uploads (avatar/banner/pro_avatar e galeria)
    extra = %i[
      name as_client as_professional active_role
      phone_number cep city state address address_number description
      avatar pro_avatar banner
    ]
    devise_parameter_sanitizer.permit(:sign_up,        keys: extra)
    devise_parameter_sanitizer.permit(:account_update, keys: extra)
  end

  def after_sign_in_path_for(resource)
    rt = sanitize_return_path(session.delete(:return_to))
    return rt if rt

    stored = sanitize_return_path(stored_location_for(resource))
    return stored if stored

    resource.respond_to?(:professional?) && resource.professional? ? dashboard_path : root_path
  end

  private

  # ✅ Garante que url_for(blob) gere o host/porta certos
  def set_active_storage_url_options
    ActiveStorage::Current.url_options = {
      protocol: request.scheme,
      host:     request.host,
      port:     request.optional_port
    }
  end

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

    # Não intervir na navegação do fluxo de profissionais
    return if controller_name == "professionals"

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
    return unless path.start_with?('/')
    return if NON_PAGE_PATHS.any? { |re| re.match?(path) }
    path
  end
end
