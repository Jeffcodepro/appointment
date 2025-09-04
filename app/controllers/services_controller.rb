class ServicesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :cities, :show, :availability, :calendar, :availability_summary]
  before_action :ensure_professional!, only: [:new, :create]
  before_action :ensure_provider_geocoded!, only: [:new, :create]

  include ActionView::Helpers::NumberHelper

  BRAZIL_BOUNDING_BOX = {
    min_lat: -34.0, max_lat: 5.5,
    min_lng: -74.0, max_lng: -34.5
  }.freeze

  # GET /services
  def index
    @states = User.where.not(state: [nil, ""])
                  .distinct
                  .pluck(:state)
                  .sort

    # Base scope com eager loading das imagens do user
    @services = Service
                  .includes(user: { images_attachments: :blob })
                  .joins(:user)

    # busca por service_id explícito (por ex. vindo de clique no mapa)
    if params[:service_id].present?
      @services = @services.where(id: params[:service_id])
    elsif params[:query].present?
      # busca textual (ajuste para seu pg_search / search interno)
      searched_ids = Service.global_search(params[:query]).select(:id)
      @services = @services.where(id: searched_ids)
    end

    # filtros por categoria e por localização do usuário (provider)
    @services = @services.where(categories: params[:category]) if params[:category].present?
    @services = @services.where(users: { state: params[:state] }) if params[:state].present?
    @services = @services.where(users: { city:  params[:city]  }) if params[:city].present?

    @services = @services.distinct

    # ---- Markers SOMENTE para quem tem geocoding válido e dentro do bounding box
    @markers = @services.filter { |service|
      u = service.user
      u.latitude.present? && u.longitude.present? &&
        u.latitude.between?(BRAZIL_BOUNDING_BOX[:min_lat], BRAZIL_BOUNDING_BOX[:max_lat]) &&
        u.longitude.between?(BRAZIL_BOUNDING_BOX[:min_lng], BRAZIL_BOUNDING_BOX[:max_lng])
    }.map do |service|
      {
        lat: service.user.latitude,
        lng: service.user.longitude,
        name: service.user.name,
        service_id: service.id,
        price: format_price(service),
        url: service_path(service)
      }
    end
  end

  def cities
    scope = User.where(role: :professional)
    scope = scope.where(state: params[:state]) if params[:state].present?

    cities = scope
               .where.not(city: [nil, ""])
               .distinct
               .order(:city)
               .pluck(:city)

    render json: cities
  end

  def availability
    service  = Service.find(params[:id])
    provider = service.user

    # parse seguro da data
    date_str = params[:date].to_s
    date =
      if date_str.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        Date.iso8601(date_str) rescue Date.current
      else
        Date.current
      end

    # bloqueia passado e fins de semana
    if date < Date.current || date.saturday? || date.sunday?
      render(json: { date: date.to_s, slots: [] }) and return
    end

    open_h   = 9
    close_h  = 18
    avg_h    = [service.average_hours.to_i, 1].max
    duration = avg_h.hours

    day_start = date.in_time_zone.change(hour: open_h,  min: 0)
    day_end   = date.in_time_zone.change(hour: close_h, min: 0)

    # agendamentos do provider que conflitam com o dia
    day_schedules = Schedule
      .for_provider(provider.id)
      .where("start_at < ? AND end_at > ?", day_end, day_start)
      .pluck(:start_at, :end_at)

    now = Time.zone.now

    slots = []
    t = day_start
    while (t + duration) <= day_end
      slot_start = t
      slot_end   = t + duration

      conflict  = day_schedules.any? { |(s_start, s_end)| s_start < slot_end && s_end > slot_start }
      after_now = (date > Date.current) || (slot_start > now)
      available = !conflict && after_now

      # 👉 Só inclui se disponível e (se for hoje) depois do horário atual
      if available
        slots << {
          start_at: slot_start.iso8601,
          end_at:   slot_end.iso8601,
          label:    "#{I18n.l(slot_start, format: :short, default: slot_start.strftime('%d/%m %H:%M'))} – " \
                    "#{I18n.l(slot_end,   format: :time,  default: slot_end.strftime('%H:%M'))}",
          available: true
        }
      end

      t += duration
    end

    render json: { date: date.to_s, slots: slots }
  end

  def availability_summary
    service   = Service.find(params[:id])
    provider  = service.user

    open_h   = 9
    close_h  = 18
    avg_h    = [service.average_hours.to_i, 1].max
    duration = avg_h.hours

    start_date = params[:start].present? ? Date.iso8601(params[:start]) : Date.current.beginning_of_month
    end_date   = params[:end].present?   ? Date.iso8601(params[:end])   : start_date.end_of_month

    range_start = start_date.in_time_zone.change(hour: open_h,  min: 0)
    range_end   = end_date.in_time_zone.change(  hour: close_h, min: 0)

    all_sched = Schedule
                  .for_provider(provider.id)
                  .where("start_at < ? AND end_at > ?", range_end, range_start)
                  .pluck(:start_at, :end_at)

    now = Time.zone.now
    fully_booked = []

    (start_date..end_date).each do |date|
      next if date.saturday? || date.sunday?

      day_start = date.in_time_zone.change(hour: open_h,  min: 0)
      day_end   = date.in_time_zone.change(hour: close_h, min: 0)

      day_sched = all_sched.select { |s_start, s_end| s_start < day_end && s_end > day_start }

      any_available = false
      t = day_start
      while (t + duration) <= day_end
        slot_start = t
        slot_end   = t + duration
        conflict   = day_sched.any? { |s_start, s_end| s_start < slot_end && s_end > slot_start }

        # 👇 mesma regra do availability: se for hoje, só conta depois de agora
        after_now  = (date > Date.current) || (slot_start > now)

        if !conflict && after_now
          any_available = true
          break
        end

        t += duration
      end

      fully_booked << date.to_s unless any_available
    end

    render json: { fully_booked: fully_booked }
  rescue ArgumentError
    render json: { error: "invalid dates" }, status: :bad_request
  end



  def calendar
    @service   = Service.find(params[:id])
    @provider  = @service.user
    @provider_schedules = Schedule.for_provider(@provider.id)
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
    render partial: "services/calendar", locals: { start_date: @start_date }
  end

  # GET /services/:id
  def show
    @service   = Service.includes(user: { images_attachments: :blob }).find(params[:id])
    @provider  = @service.user
    @services_from_provider = @provider.services.order(:categories, :subcategories)

    @provider_schedules = Schedule.for_provider(@provider.id)


    # mapa: só o local do profissional
    @markers = [{
      lat:  @provider.latitude,
      lng:  @provider.longitude,
      name: @provider.name,
      service_id: @service.id,
      price: @service.price_hour.format,
      url: service_path(@service),
    }]
    # marcador do provider (só cria se tiver geo válido)
    @markers = []
    if @provider.latitude.present? && @provider.longitude.present?
      @markers << {
        lat:  @provider.latitude,
        lng:  @provider.longitude,
        name: @provider.name,
        service_id: @service.id,
        price: format_price(@service),
        url: service_path(@service)
      }
    end
  end

  # POST /services
  def create
    @service = Service.new(service_params)
    @service.user = current_user

    if @service.save
      redirect_to dashboard_path, notice: "Serviço criado com sucesso."
    else
      flash.now[:alert] = "Não foi possível criar o serviço. Verifique os campos."
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Apenas PROFESSIONAL pode criar serviços
  def ensure_professional!
    return unless user_signed_in?

    unless current_user.professional?
      redirect_to root_path, alert: "Somente profissionais podem criar serviços."
    end
  end

  # Profissional precisa ter endereço geocodado para criar serviços
  def ensure_provider_geocoded!
    return unless user_signed_in? && current_user.professional?

    if current_user.latitude.blank? || current_user.longitude.blank?
      begin
        current_user.inject_coordinates
      rescue => _e
        redirect_to edit_user_registration_path,
                    alert: "Complete e valide seu endereço (CEP, rua, número, cidade e estado) para criar serviços e aparecer no mapa."
      end
    end
  end

  def service_params
    # Alinhado ao seu seed/model:
    # - categories / subcategories (strings)
    # - price_hour (MoneyRails -> monetized :price_hour_cents)
    # - average_hours (integer)
    params.require(:service).permit(
      :name, :description,
      :categories, :subcategories,
      :price_hour, :average_hours
    )
  end

  def format_price(service)
    if service.respond_to?(:price_hour) && service.price_hour.present?
      service.price_hour.format
    else
      cents = service.try(:price_hour_cents).to_i
      number_to_currency(cents / 100.0, unit: "R$ ", separator: ",", delimiter: ".")
    end
  end

  def safe_date(value)
    return Date.current if value.blank?
    Date.parse(value)
  rescue ArgumentError
    Date.current
  end

end
