class RolesController < ApplicationController
  before_action :authenticate_user!

  def update
    role = params.require(:role).to_s
    unless %w[client professional].include?(role)
      redirect_back fallback_location: root_path, alert: "Papel inválido" and return
    end

    # Habilitar papel quando vier enable=1 (usado pelos modais)
    if params[:enable].present?
      current_user.enable_role!(role) unless current_user.has_role?(role)

      if role == "professional"
        current_user.switch_role!("professional")
        redirect_to edit_profile_path(current_user), notice: "Habilitamos seu perfil profissional. Complete seu perfil." and return
      else
        current_user.switch_role!("client")
        redirect_to services_path, notice: "Habilitamos seu perfil de cliente." and return
      end
    end

    # Alternância simples quando o papel já existe
    first_time_pro = (role == "professional" && !current_user.as_professional?)
    current_user.switch_role!(role)

    if role == "client"
      # ✅ Sempre redireciona para a listagem de serviços + toast claro
      redirect_to services_path, notice: "Você está usando a visão de cliente." and return
    end

    # Profissional
    if first_time_pro
      redirect_to edit_profile_path(current_user), notice: "Habilitamos sua visão profissional. Complete seu perfil."
    else
      redirect_to dashboard_path, notice: "Você está usando a visão de profissional."
    end
  end
end
