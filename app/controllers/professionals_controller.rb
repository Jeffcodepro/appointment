# app/controllers/professionals_controller.rb
class ProfessionalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  before_action :ensure_owner!
  before_action :ensure_can_edit_professional!

  def show
    @profile = @user
    render :edit # ou crie uma view show própria, se preferir
  end

  def new
    @profile = @user
  end

  def create
    @profile = @user

    # Captura os uploads ANTES de atribuir os demais atributos
    avatar = params.dig(:user, :avatar)
    banner = params.dig(:user, :banner)

    @profile.assign_attributes(profile_params.except(:avatar, :banner))
    @profile.avatar.attach(avatar) if avatar.present?
    @profile.banner.attach(banner) if banner.present?

    if @profile.save
      @profile.update_column(:profile_completed, true)
      redirect_to dashboard_path, notice: "Perfil profissional salvo."
    else
      flash.now[:alert] = @profile.errors.full_messages.to_sentence.presence || "Não foi possível salvar. Revise os campos."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @profile = @user
  end

  def update
    @profile = @user
    Rails.logger.info("[PRO UPDATE] incoming keys: #{params[:user]&.keys}")

    # Captura os uploads ANTES de atribuir os demais atributos
    avatar = params.dig(:user, :avatar)
    banner = params.dig(:user, :banner)

    @profile.assign_attributes(profile_params.except(:avatar, :banner))
    @profile.avatar.attach(avatar) if avatar.present?
    @profile.banner.attach(banner) if banner.present?

    if @profile.save
      @profile.update_column(:profile_completed, true) unless @profile.profile_completed?
      redirect_to dashboard_path, notice: "Perfil profissional atualizado."
    else
      flash.now[:alert] = @profile.errors.full_messages.to_sentence.presence || "Não foi possível salvar. Revise os campos."
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    # edição do próprio perfil
    @user = User.find(params[:user_id] || params[:id] || current_user.id)
  end

  def ensure_owner!
    redirect_to root_path, alert: "Acesso negado." unless current_user && current_user.id == @user.id
  end

  # Permite editar o perfil profissional se o PAPEL estiver habilitado,
  # independentemente da visão atual (client/professional).
  # Assim, mesmo se a pessoa estiver na visão de cliente, ela consegue ajustar o perfil pro.
  def ensure_can_edit_professional!
    return if action_name.in?(%w[new create]) # permitir fluxo de criação
    return if @user.as_professional?

    redirect_to root_path, alert: "Ative o perfil profissional para continuar."
  end

  def profile_params
    params.require(:user).permit(
      :name, :description, :phone_number,
      :cep, :address, :address_number, :city, :state,
      :avatar, :banner
    )
  end
end
