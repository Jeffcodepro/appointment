class ProfessionalsController < ApplicationController
  before_action :set_user
  before_action :ensure_owner!
  before_action :ensure_professional!

  def new
    @profile = @user
  end

  def create
    @profile = @user
    if @profile.update(profile_params)
      @profile.update!(profile_completed: true)
      redirect_to dashboard_path, notice: "Perfil profissional salvo."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @profile = @user
  end

  def update
    @profile = @user
    if @profile.update(profile_params)
      @profile.update!(profile_completed: true) unless @profile.profile_completed?
      redirect_to dashboard_path, notice: "Perfil profissional atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def ensure_owner!
    redirect_to root_path, alert: "Acesso negado." unless current_user == @user
  end

  def ensure_professional!
    redirect_to root_path, alert: "Apenas profissionais." unless current_user.professional?
  end

  # Campos adicionais (do próprio User) + avatar
  def profile_params
    params.require(:user).permit( :name, :description, :cep, :address, :phone_number, :avatar, :banner)
  end
end
