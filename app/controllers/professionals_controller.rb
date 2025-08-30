class ProfessionalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  before_action :ensure_owner!
  before_action :ensure_professional!


  def show
    @profile = @user
    render :edit # ou uma view própria de show
  end

  def new
    @profile = @user
  end

  def create
    @profile = @user
    if @profile.update(profile_params)
      @profile.update_column(:profile_completed, true)
      redirect_to dashboard_path, notice: "Perfil profissional salvo."
    else
      flash.now[:alert] = "Não foi possível salvar. Revise os campos."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @profile = @user
  end

  def update
    @profile = @user
    Rails.logger.info("[PRO UPDATE] incoming keys: #{params[:user]&.keys}")

    if @profile.update(profile_params)
      @profile.update_column(:profile_completed, true) unless @profile.profile_completed?
      redirect_to dashboard_path, notice: "Perfil profissional atualizado."
    else
      flash.now[:alert] = "Não foi possível salvar. Revise os campos."
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id] || params[:id] || current_user.id)
  end

  def ensure_owner!
    redirect_to root_path, alert: "Acesso negado." unless current_user && current_user.id == @user.id
  end

  def ensure_professional!
    redirect_to root_path, alert: "Apenas profissionais." unless current_user&.professional?
  end

  # 👉 agora permite número, cidade e UF
  def profile_params
    params.require(:user).permit(
      :name, :description, :phone_number,
      :cep, :address, :address_number, :city, :state,
      :avatar, :banner
    )
  end
end
