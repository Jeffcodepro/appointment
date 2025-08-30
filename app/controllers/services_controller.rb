class ServicesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :cities, :show, :availability]
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

  # GET /services/cities.json?state=SP
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

  # GET /services/:id/availability.json?date=2025-09-02
  def availability
    service  = Service.find(params[:id])
    provider = service.user
    date     = safe_date(params[:date])

    open_h   = 9
    close_h  = 18
    duration = (service.average_hours.presence || 1).hours

    day_start = date.in_time_zone.change(hour: open_h,  min: 0)
    day_end   = date.in_time_zone.change(hour: close_h, min: 0)

    # agendas do provider que batem nesse dia (confirmadas ou não)
    day_schedules = Schedule
                      .for_provider(provider.id)
                      .where("start_at < ? AND end_at > ?", day_end, day_start)
                      .pluck(:start_at, :end_at)

    # gera slots a cada 30min
    step = 30.minutes
    slots = []
    t = day_start
    while (t + duration) <= day_end
      slot_start = t
      slot_end   = t + duration

      conflict = day_schedules.any? { |(s_start, s_end)| s_start < slot_end && s_end > slot_start }
      slots << { start_at: slot_start, end_at: slot_end } unless conflict

      t += step
    end

    render json: {
      date: date.to_s,
      slots: slots.map { |s|
        {
          start_at: s[:start_at].iso8601,
          end_at:   s[:end_at].iso8601,
          label:    "#{I18n.l(s[:start_at], format: :short)} – #{I18n.l(s[:end_at], format: :time)}"
        }
      }
    }
  end

  # GET /services/:id
  def show
    @service   = Service.includes(user: { images_attachments: :blob }).find(params[:id])
    @provider  = @service.user
    @services_from_provider = @provider.services.order(:categories, :subcategories)

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
