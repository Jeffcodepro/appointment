# app/controllers/professionals_controller.rb
class ProfessionalsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  before_action :ensure_owner!
  before_action :ensure_can_edit_professional!

  def show
    @profile = @user
    render :edit
  end

  def new
    @profile = @user
  end

  def create
    @profile = @user

    pro_avatar_io = params.dig(:user, :pro_avatar)
    banner_io     = params.dig(:user, :banner)

    @profile.assign_attributes(profile_params.except(:pro_avatar, :banner))
    @profile.pro_avatar.attach(pro_avatar_io) if pro_avatar_io.present?
    @profile.banner.attach(banner_io)         if banner_io.present?

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

    pro_avatar_io = params.dig(:user, :pro_avatar)
    banner_io     = params.dig(:user, :banner)

    @profile.assign_attributes(profile_params.except(:pro_avatar, :banner))
    @profile.pro_avatar.attach(pro_avatar_io) if pro_avatar_io.present?
    @profile.banner.attach(banner_io)         if banner_io.present?

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
    @user = User.find(params[:user_id] || params[:id] || current_user.id)
  end

  def ensure_owner!
    redirect_to root_path, alert: "Acesso negado." unless current_user && current_user.id == @user.id
  end

  def ensure_can_edit_professional!
    return if action_name.in?(%w[new create])
    return if @user.as_professional?
    redirect_to root_path, alert: "Ative o perfil profissional para continuar."
  end

  def profile_params
    params.require(:user).permit(
      :name, :description, :phone_number,
      :cep, :address, :address_number, :city, :state,
      :pro_avatar, :banner
    )
  end
end
