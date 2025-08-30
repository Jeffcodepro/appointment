module ApplicationHelper
  def professional?
    current_user.role == 'professional'
  end

  def has_services?
    current_user.services.any?
  end
end
