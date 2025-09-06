# app/controllers/schedules_controller.rb
require "csv"

class SchedulesController < ApplicationController
  before_action :authenticate_user!, only: [:create, :show, :history, :cancel, :accept, :reject]

  def create
    service = Service.find(params[:service_id])
    start_at = Time.zone.parse(params[:start_at])
    end_at   = Time.zone.parse(params[:end_at])

    schedule = Schedule.new(
      client:       current_user,
      professional: service.user,
      service:      service,
      start_at:     start_at,
      end_at:       end_at,
      status:       :pending
    )

    schedule.user_id = service.user_id if schedule.has_attribute?(:user_id) && schedule.user_id.blank?

    if schedule.save
      redirect_to service_path(service), notice: "Solicitação enviada! Aguarde a confirmação do profissional."
    else
      redirect_to service_path(service), alert: schedule.errors.full_messages.to_sentence
    end
  end


  def show
    @schedule = Schedule.includes(:service, :client, :professional, :messages).find(params[:id])
    authorize_participation!(@schedule)

    @conversation = Conversation.find_by(
      client_id:       @schedule.client_id,
      professional_id: @schedule.professional_id,
      service_id:      @schedule.service_id
    )

    conv_msgs_ids = @conversation ? @conversation.messages.select(:id) : Message.none
    @messages = Message.where(id: @schedule.messages.select(:id)).or(Message.where(id: conv_msgs_ids))
                      .includes(:user).order(:created_at)

    @message  = Message.new
  end



  def history
    base = Schedule.includes(:service, :client, :professional)
                  .where("client_id = :id OR professional_id = :id", id: current_user.id)

    @role = params[:role].presence_in(%w[client professional]) || "all"
    base =
      case @role
      when "client"       then base.where(client_id: current_user.id)
      when "professional" then base.where(professional_id: current_user.id)
      else                      base
      end

    @status = params[:status].presence
    has_status = @status.present? && Schedule.statuses.key?(@status)
    has_dates  = params[:start_date].present? || params[:end_date].present?
    has_query  = params[:query].present?
    role_filter_applied = params.key?(:role) && @role != "all"

    no_filters = !has_status && !has_dates && !has_query && !role_filter_applied

    # ===== Filtros opcionais =====
    base = base.where(status: @status) if has_status

    # Texto (join só se necessário)
    if has_query
      pattern = "%#{params[:query].to_s.strip}%"
      base = base
        .joins("LEFT JOIN services s ON s.id = schedules.service_id")
        .joins("LEFT JOIN users u_client ON u_client.id = schedules.client_id")
        .joins("LEFT JOIN users u_prof   ON u_prof.id = schedules.professional_id")
        .joins("LEFT JOIN messages m     ON m.schedule_id = schedules.id")
        .where(
          "s.name ILIKE :q OR s.categories ILIKE :q OR s.subcategories ILIKE :q
          OR u_client.name ILIKE :q OR u_prof.name ILIKE :q
          OR m.content ILIKE :q",
          q: pattern
        ).distinct
    end

    # Datas: só aplica se houve algum filtro (status/query/role) OU o usuário selecionou datas.
    unless no_filters
      start_date =
        if params[:start_date].present?
          (Date.parse(params[:start_date]) rescue Date.today - 29)
        else
          Date.today - 29
        end
      end_date =
        if params[:end_date].present?
          (Date.parse(params[:end_date]) rescue Date.today)
        else
          Date.today
        end

      base = base.where(start_at: start_date.beginning_of_day..end_date.end_of_day)
    end

    @schedules = base.order(start_at: :desc)

    respond_to do |format|
      format.html
      format.csv do
        send_data generate_history_csv(@schedules),
          filename: "historico-#{Date.today}.csv",
          type: "text/csv; charset=utf-8"
      end
    end
  end



  def cancel
    schedule = Schedule.find(params[:id])
    authorize_participation!(schedule)

    if schedule.canceled? || schedule.completed? || schedule.no_show?
      redirect_back fallback_location: service_history_path, alert: "Este agendamento não pode ser cancelado."
      return
    end

    Schedule.transaction do
      schedule.update!(status: :canceled)
      note = params[:note].to_s.strip
      if note.present?
        schedule.messages.create!(user: current_user, content: "Cancelamento: #{note}")
      end
    end

    msg = params[:note].present? ? "Agendamento cancelado e mensagem enviada." : "Agendamento cancelado."
    redirect_back fallback_location: service_history_path, notice: msg
  end

  def accept
    schedule = Schedule.find(params[:id])
    authorize_participation!(schedule)

    unless current_user.id == schedule.professional_id
      redirect_back fallback_location: schedule_path(schedule), alert: "Apenas o profissional pode confirmar." and return
    end
    if schedule.canceled? || schedule.completed? || schedule.no_show?
      redirect_back fallback_location: schedule_path(schedule), alert: "Este agendamento não pode ser confirmado." and return
    end

    Schedule.transaction do
      attrs = { accepted_professional: true }
      attrs[:confirmed] = true if schedule.has_attribute?(:confirmed)

      # seta o melhor status disponível no enum
      if Schedule.respond_to?(:statuses)
        if Schedule.statuses.key?("confirmed")
          attrs[:status] = :confirmed
        elsif Schedule.statuses.key?("accepted")
          attrs[:status] = :accepted
        end
      end

      schedule.update!(attrs)
    end

    redirect_to schedule_path(schedule), notice: "Agendamento confirmado."
  end

  def reject
    schedule = Schedule.find(params[:id])
    authorize_participation!(schedule)

    unless current_user.id == schedule.professional_id
      redirect_back fallback_location: schedule_path(schedule), alert: "Apenas o profissional pode recusar." and return
    end
    if schedule.canceled? || schedule.completed? || schedule.no_show?
      redirect_back fallback_location: schedule_path(schedule), alert: "Este agendamento não pode ser recusado." and return
    end

    note = params[:note].to_s.strip

    Schedule.transaction do
      attrs = { accepted_professional: false, confirmed: false }
      attrs.delete(:confirmed) unless schedule.has_attribute?(:confirmed)

      if Schedule.respond_to?(:statuses)
        if Schedule.statuses.key?("rejected")
          attrs[:status] = :rejected
        else
          attrs[:status] = :canceled if Schedule.statuses.key?("canceled")
        end
      end

      schedule.update!(attrs)
      schedule.messages.create!(user: current_user, content: "Recusado pelo profissional#{": #{note}" if note.present?}") if note.present?
    end

    redirect_to schedule_path(schedule), notice: "Agendamento recusado."
  end


  private

  def generate_history_csv(schedules)
    CSV.generate(headers: true) do |csv|
      csv << ["ID", "Serviço", "Categoria", "Subcategoria", "Cliente", "Profissional", "Início", "Fim", "Status"]
      schedules.find_each do |s|
        csv << [
          s.id,
          s.service&.name,
          s.service&.categories,
          s.service&.subcategories,
          s.client&.name,
          s.professional&.name,
          I18n.l(s.start_at, format: :short),
          (I18n.l(s.end_at, format: :short) if s.end_at),
          s.status
        ]
      end
    end
  end

  def authorize_participation!(schedule)
    permitted_ids = [schedule.client_id, schedule.professional_id, schedule.service&.user_id].compact
    return if current_user && permitted_ids.include?(current_user.id)
    redirect_to root_path, alert: "Acesso negado."
  end
end
