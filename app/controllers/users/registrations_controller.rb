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
      # Captura o arquivo antes de remover do hash
      avatar_io = account_update_params[:avatar]

      # Atualiza campos (com/sem senha)
      updated =
        if account_update_params[:password].blank? && account_update_params[:password_confirmation].blank?
          resource.update_without_password(account_update_params.except(:current_password, :avatar))
        else
          resource.update(account_update_params.except(:avatar))
        end

      # Anexa avatar se veio arquivo
      if avatar_io.present?
        resource.avatar.attach(avatar_io)
        resource.save(validate: false)
      end

      if updated
        set_flash_message :notice, :updated
        redirect_to after_update_path_for(resource)
      else
        clean_up_passwords resource
        set_minimum_password_length
        respond_with resource
      end
    end

    protected

    def configure_permitted_parameters
      keys = [
        :name, :email, :avatar,
        :active_role, :as_client, :as_professional
      ]
      devise_parameter_sanitizer.permit(:sign_up,        keys: keys)
      devise_parameter_sanitizer.permit(:account_update, keys: keys)
    end

    def update_resource(resource, params)
      if params[:password].blank? && params[:password_confirmation].blank?
        resource.update_without_password(params.except(:current_password))
      else
        super
      end
    end

    def after_update_path_for(_resource)
      edit_user_registration_path
    end

    private

    def set_profile
      @profile = current_user
    end
  end
end
