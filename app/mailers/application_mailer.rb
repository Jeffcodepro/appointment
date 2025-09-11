class ApplicationMailer < ActionMailer::Base
  DEFAULT_FROM = ENV["SMTP_USERNAME"].presence || Rails.application.credentials.dig(:smtp, :user_name)

  # Em dev, falhe se continuar vazio
  if Rails.env.development? && DEFAULT_FROM.blank?
    raise "SMTP_USERNAME (ou credentials smtp.user_name) ausente — defina para testar e-mails."
  end

  default from:    -> { "Appointment <noreply@company.com>" },
          reply_to: -> { DEFAULT_FROM }
  layout "mailer"
end
