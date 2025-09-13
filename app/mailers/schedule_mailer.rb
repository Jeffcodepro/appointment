# app/mailers/schedule_mailer.rb
class ScheduleMailer < ApplicationMailer
  before_action :load_schedule_context

  # ——— E-mails para o PROFISSIONAL ———
  def booking_request_to_professional
    return unless @professional&.email.present?

    # opcional: usado no preheader do layout (se você estiver usando content_for :preheader)
    @preheader = "#{@client&.name} solicitou #{@subcat} para #{I18n.l(@start, format: :long) if @start}"

    mail(
      to: @professional.email,
      subject: "[Appointment] Novo agendamento aguardando sua confirmação",
      reply_to: (@client&.email.presence || ApplicationMailer::DEFAULT_FROM)
    )
  end

  # ——— E-mails para o CLIENTE ———

  # Use este se quiser enviar um recibo ao cliente logo após ele criar o agendamento
  def booking_created_to_client
    @confirmed = false
    @preheader = "Recebemos seu agendamento de #{@subcat} para #{I18n.l(@start, format: :long) if @start}"

    mail(
      to: @client.email,
      subject: "[Appointment] Recebemos seu agendamento",
      reply_to: (@professional&.email.presence || ApplicationMailer::DEFAULT_FROM)
    )
  end

  def booking_confirmed_to_client
    @confirmed = true
    @preheader = "Confirmado: #{@subcat} em #{I18n.l(@start, format: :long) if @start}"

    mail(
      to: @client.email,
      subject: "[Appointment] Seu agendamento foi confirmado por #{@professional&.name || 'o profissional'}",
      reply_to: (@professional&.email.presence || ApplicationMailer::DEFAULT_FROM)
    )
  end

  def booking_declined_to_client
    @preheader = "O profissional recusou seu agendamento de #{@subcat}"

    mail(
      to: @client.email,
      subject: "[Appointment] O profissional recusou seu agendamento",
      reply_to: (@professional&.email.presence || ApplicationMailer::DEFAULT_FROM)
    )
  end

  def booking_canceled_by_professional_to_client
    @preheader = "Seu agendamento de #{@subcat} foi cancelado pelo profissional"

    mail(
      to: @client.email,
      subject: "[Appointment] Seu agendamento foi cancelado pelo profissional",
      reply_to: (@professional&.email.presence || ApplicationMailer::DEFAULT_FROM)
    )
  end

  def confirmation_reminder_to_professional
    @schedule     = params[:schedule]
    @client       = User.find_by(id: @schedule.client_id)
    @professional = User.find_by(id: @schedule.professional_id)
    @service      = Service.find_by(id: @schedule.service_id)

    tz     = "America/Sao_Paulo"
    @start = @schedule.start_at&.in_time_zone(tz)
    @end   = @schedule.end_at&.in_time_zone(tz)

    return unless @professional&.email.present?

    mail(
      to: @professional.email,
      subject: "[Appointment] Lembrete: confirme o agendamento de #{@client&.name}",
      reply_to: (@client&.email.presence || ApplicationMailer::DEFAULT_FROM)
    )
  end

  private

  def load_schedule_context
    @schedule     = params[:schedule]
    @client       = User.find_by(id: @schedule.client_id)
    @professional = User.find_by(id: @schedule.professional_id)
    @service      = Service.find_by(id: @schedule.service_id)

    # preferência: subcategoria → categoria → nome do serviço
    @subcat       = @service&.subcategories.presence ||
                    @service&.categories.presence   ||
                    @service&.name

    # timezone único para padronizar data/hora no e-mail
    tz     = "America/Sao_Paulo"
    @start = @schedule.start_at&.in_time_zone(tz)
    @end   = @schedule.end_at&.in_time_zone(tz)
  end
end
