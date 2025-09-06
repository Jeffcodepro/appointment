module ApplicationHelper
  def professional?
    current_user.role == 'professional'
  end

  def has_services?
    current_user.services.any?
  end

  def format_duration_minutes(mins)
    return nil if mins.blank?
    mins = mins.to_i
    return "#{mins} min" if mins < 60
    h = mins / 60
    m = mins % 60
    m.zero? ? "#{h} h" : "#{h} h #{m} min"
  end

  def brl_from_cents(cents)
    number_to_currency(cents.to_i / 100.0, unit: "R$ ", separator: ",", delimiter: ".", precision: 2)
  end

  def first_name(user)
    name = user&.name.to_s.strip
    return name.split(/\s+/).first if name.present?
    user&.email.to_s.split("@").first
  end
end
