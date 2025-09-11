class ScheduleMailer < ApplicationMailer

  def booking_confirmed_to_client
    @schedule     = params[:schedule]
    @client       = User.find_by(id: @schedule.client_id)
    @professional = User.find_by(id: @schedule.professional_id)
    @service      = Service.find_by(id: @schedule.service_id)

    tz     = "America/Sao_Paulo"
    @start = @schedule.start_at&.in_time_zone(tz)
    @end   = @schedule.end_at&.in_time_zone(tz)

    mail(
      to: @client.email,
      subject: "[Appointment] Seu agendamento foi confirmado por #{@professional&.name || 'o profissional'}",
      reply_to: (@professional&.email.presence || ApplicationMailer::DEFAULT_FROM)
    )
  end

  def booking_declined_to_client
    @schedule     = params[:schedule]
    @client       = User.find_by(id: @schedule.client_id)
    @professional = User.find_by(id: @schedule.professional_id)
    @service      = Service.find_by(id: @schedule.service_id)
    tz            = "America/Sao_Paulo"
    @start        = @schedule.start_at&.in_time_zone(tz)
    @end          = @schedule.end_at&.in_time_zone(tz)

    mail(
      to: @client.email,
      subject: "[Appointment] O profissional recusou seu agendamento",
      reply_to: (@professional&.email.presence || ApplicationMailer::DEFAULT_FROM)
    )
  end

  def booking_canceled_by_professional_to_client
    @schedule     = params[:schedule]
    @client       = User.find_by(id: @schedule.client_id)
    @professional = User.find_by(id: @schedule.professional_id)
    @service      = Service.find_by(id: @schedule.service_id)
    tz            = "America/Sao_Paulo"
    @start        = @schedule.start_at&.in_time_zone(tz)
    @end          = @schedule.end_at&.in_time_zone(tz)

    mail(
      to: @client.email,
      subject: "[Appointment] Seu agendamento foi cancelado pelo profissional",
      reply_to: (@professional&.email.presence || ApplicationMailer::DEFAULT_FROM)
    )
  end

  def booking_request_to_professional
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
      subject: "[Appointment] Novo agendamento aguardando sua confirmação",
      reply_to: (@client&.email.presence || ApplicationMailer::DEFAULT_FROM)
    )
  end
end
