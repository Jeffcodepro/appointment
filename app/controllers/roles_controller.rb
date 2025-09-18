# app/controllers/roles_controller.rb
class RolesController < ApplicationController
  before_action :authenticate_user!

  def update
    to = params[:role].to_s
    unless %w[client professional].include?(to)
      return redirect_back(fallback_location: root_path, alert: "Papel inválido.")
    end

    user = current_user
    from = user.active_role

    # Habilita o papel se veio "enable=1"
    if truthy?(params[:enable])
      user.as_client       = true if to == "client"
      user.as_professional = true if to == "professional"
    end

    # Bloqueia alternância se o papel não estiver habilitado
    if to == "client" && !user.as_client?
      return redirect_back(fallback_location: root_path, alert: "Ative o perfil de cliente para continuar.")
    end
    if to == "professional" && !user.as_professional?
      return redirect_back(fallback_location: root_path, alert: "Ative o perfil profissional para continuar.")
    end

    # Sincroniza active_role + enum
    user.active_role = to
    user.role = to if user.class.defined_enums.key?("role")
    user.save!(validate: false)

    redirect_to after_switch_path(to, request.referer),
                notice: "Visão alterada para #{to == 'client' ? 'Cliente' : 'Profissional'}."
  rescue => e
    Rails.logger.error("[ROLE SWITCH][ERROR] user=#{current_user&.id} to=#{params[:role]} #{e.class}: #{e.message}")
    redirect_back fallback_location: root_path, alert: "Não foi possível alternar a visão."
  end

  private

  def truthy?(v)
    v.in?([true, "1", 1, "true", "on", "yes"])
  end

  # ===== Regras de equivalência entre telas =====
  # Professional -> Client
  # - /dashboard            -> services#index (home)
  # - /history              -> /history
  # - /conversations(/:id)  -> /conversations
  # - /services/mine        -> /history
  # - /services/new         -> /history
  #
  # Client -> Professional
  # - services#index (home) -> /dashboard
  # - /history              -> /history
  # - /conversations(/:id)  -> /conversations
  def after_switch_path(to_role, referer)
    ref_path = begin
      URI.parse(referer.to_s).path
    rescue
      ""
    end

    # helpers para comparação robusta
    conv_root = conversations_path
    is_conv   = ref_path.start_with?(conv_root)

    if to_role == "client"
      return services_path        if ref_path == dashboard_path || ref_path == root_path || ref_path == services_path
      return service_history_path if ref_path == mine_services_path || ref_path == new_service_path
      return service_history_path if ref_path == service_history_path
      return conversations_path   if is_conv
      # fallback (cliente): home
      services_path
    else # to_role == "professional"
      return dashboard_path       if ref_path == root_path || ref_path == services_path
      return service_history_path if ref_path == service_history_path
      return conversations_path   if is_conv
      # fallback (profissional): dashboard
      dashboard_path
    end
  end
end
