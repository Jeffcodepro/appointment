# app/controllers/users/registrations_controller.rb
class Users::RegistrationsController < Devise::RegistrationsController
  def update
    self.resource = resource_class.to_adapter.get!(send(:"current_#{resource_name}").to_key)
    prev_unconfirmed_email = resource.unconfirmed_email if resource.respond_to?(:unconfirmed_email)

    if update_resource(resource, account_update_params)
      set_flash_message_for_update(resource, prev_unconfirmed_email)
      bypass_sign_in resource, scope: resource_name if sign_in_after_change_password?
      redirect_to after_update_path_for(resource)
    else
      clean_up_passwords resource
      set_minimum_password_length
      flash.now[:error] = t("simple_form.error_notification.default_message")
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  def update_resource(resource, params)
    if params[:password].present? || params[:email].present?
      super
    else
      params.delete(:current_password)

      avatar = params.delete(:avatar)
      banner = params.delete(:banner)
      resource.avatar.attach(avatar) if avatar
      resource.banner.attach(banner) if banner

      resource.assign_attributes(params)
      resource.save(validate: false)
    end
  end

  def after_update_path_for(_resource)
    dashboard_path
  end
end
