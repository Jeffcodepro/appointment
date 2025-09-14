# app/controllers/users/registrations_controller.rb
module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :authenticate_user!
    before_action :set_profile, only: [:edit, :update]
    before_action :configure_permitted_parameters, if: :devise_controller?

    def edit
      super
    end

    def update
      super
    end

    protected

    # Campos extras permitidos
    def configure_permitted_parameters
      keys = [
        :name, :avatar, :email,
        # estes flags existem no modelo e podem ser mantidos
        :active_role, :as_client, :as_professional
      ]
      devise_parameter_sanitizer.permit(:sign_up,        keys: keys)
      devise_parameter_sanitizer.permit(:account_update, keys: keys)
    end

    # Ao atualizar a conta: não exigir senha atual se não for alterar a senha
    def update_resource(resource, params)
      if params[:password].blank? && params[:password_confirmation].blank?
        resource.update_without_password(params.except(:current_password))
      else
        super
      end
    end

    def after_update_path_for(resource)
      edit_user_registration_path
    end

    private

    def set_profile
      @profile = current_user
    end
  end
end
