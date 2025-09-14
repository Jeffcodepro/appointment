class ServicesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :cities, :show, :availability, :calendar, :availability_summary]
  before_action :ensure_professional!, only: [:new, :create, :destroy, :mine, :edit, :update]
  before_action :ensure_provider_geocoded!, only: [:new, :create]

  # Captura qualquer find que não ache registro e trata com redirect amigável
  rescue_from ActiveRecord::RecordNotFound, with: :service_not_found

  # Carrega @service quando necessário
  before_action :set_service, only: [:show, :destroy]
  before_action :set_owned_service, only: [:edit, :update]



  include ActionView::Helpers::NumberHelper

  BRAZIL_BOUNDING_BOX = {
    min_lat: -34.0, max_lat: 5.5,
    min_lng: -74.0, max_lng: -34.5
  }.freeze

  # GET /services
  def index
    # estados com serviço
    @states = Service.joins(:user)
                     .where.not(users: { state: [nil, ""] })
                     .distinct
                     .order('users.state')
                     .pluck('users.state')

    scope = Service.with_user

    if params[:query].present?
      q = params[:query].to_s.squish
      scope = if looks_like_address?(q)
                scope.merge(Service.address_ilike(q))
              else
                scope.merge(Service.global_search(q))
              end
    end

    scope = scope.where(id: params[:service_id]) if params[:service_id].present?
    scope = scope.where(categories: params[:category]) if params[:category].present?
    scope = scope.joins(:user).where(users: { state: params[:state] }) if params[:state].present?
    scope = scope.joins(:user).where(users: { city:  params[:city]  }) if params[:city].present?

    @services = scope.order(created_at: :desc).limit(60)

    @markers  = @services.map do |s|
      next unless s.user.latitude && s.user.longitude
      {
        lat:   s.user.latitude,
        lng:   s.user.longitude,
        price: ActionController::Base.helpers.number_to_currency(s.price_hour, unit: "R$"),
        name:  s.name,
        url:   service_path(s),
        service_id: s.id,
        info_window_html: "<strong>#{ERB::Util.h(s.name)}</strong><br>#{ERB::Util.h(s.user.address)}"
      }
    end.compact
  end

  # GET /services/cities
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

  # GET /services/:id/availability
  def availability
    service  = Service.find(params[:id])
    provider = service.user

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

    rel = Schedule.for_provider(provider.id).blocking


    # agendamentos do provider que conflitam com o dia
    day_schedules = rel
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

  # GET /services/:id/availability_summary
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

    rel = Schedule.for_provider(provider.id).blocking

    all_sched = rel
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

  # GET /services/:id/calendar
  def calendar
    @service   = Service.find(params[:id])
    @provider  = @service.user

    @provider_schedules =
      Schedule.for_provider(@provider.id)
              .where.not(status: :canceled, canceled_by: Schedule.canceled_bies[:client])

    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
    render partial: "services/calendar", locals: { start_date: @start_date }
  end

  # GET /services/:id
  def show
    # @service já vem do before_action :set_service
    @provider  = @service.user
    @services_from_provider = @provider.services
                                      .where.not(id: @service.id) # evita repetir o atual
                                      .order(:categories, :subcategories)

    @provider_schedules =
      Schedule.for_provider(@provider.id)
              .where.not(status: :canceled, canceled_by: Schedule.canceled_bies[:client])

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

  # GET /services/new
  def new
    @service = current_user.services.new
    preload_from_last if params[:last_service_id].present?
  end

  def create
    @service = Service.new(service_params)
    @service.user = current_user

    if @service.save
      if params[:save_and_new].present?
        redirect_to new_service_path, notice: "Serviço salvo. Cadastre o próximo."
      else
        redirect_to dashboard_path, notice: "Serviço criado com sucesso."
      end
    else
      # ✅ Mostra as mensagens reais
      flash.now[:alert] = @service.errors.full_messages.to_sentence.presence || "Não foi possível criar o serviço. Verifique os campos."
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /services/:id
  def destroy
    # garante que é do dono
    service = current_user.services.find(params[:id])

    # Bloqueia exclusão se houver agendamentos futuros
    has_future = Schedule.where(service_id: service.id)
                         .where('start_at >= ?', Time.zone.now)
                         .exists?

    if has_future
      redirect_back fallback_location: dashboard_path,
                    alert: "Não é possível excluir este serviço: existem agendamentos futuros. Cancele-os antes."
    else
      service.destroy
      redirect_back fallback_location: dashboard_path,
                    notice: "Serviço excluído com sucesso."
    end
  end

  def mine
    redirect_to new_user_session_path and return unless user_signed_in?
    @services = current_user.services.order(created_at: :desc)
  end

  def edit
  end

  def update
    if @service.update(service_params)
      redirect_to mine_services_path, notice: "Serviço atualizado com sucesso."
    else
      flash.now[:alert] = @service.errors.full_messages.to_sentence.presence || "Não foi possível atualizar. Verifique os campos."
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_service
    # Usamos find normal para acionar o rescue_from caso não exista
    @service = Service.includes(user: { images_attachments: :blob }).find(params[:id])
  end

  def service_not_found
    redirect_to services_path, alert: "Serviço não encontrado. Ele pode ter sido removido."
  end

  # Apenas PROFESSIONAL pode criar/excluir serviços
  def ensure_professional!
    return unless user_signed_in?
    unless current_user.professional?
      redirect_to root_path, alert: "Somente profissionais podem realizar esta ação."
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
    params.require(:service).permit(
      :name, :description,
      # aceita as duas chaves para não quebrar nada existente
      :category, :categories, :subcategories,
      :price_hour, :average_hours,
      service_subcategories_attributes: [
        :id, :name, :price_hour, :average_hours, :description, :_destroy
      ]
    )
  end


  def preload_from_last
    last = current_user.services.find_by(id: params[:last_service_id])
    return unless last

    @service.assign_attributes(
      name:        last.name,
      categories:  last.categories,
      description: last.description
    )
    # zera campos variáveis por tipo:
    @service.subcategories = nil
    @service.price_hour    = nil
    @service.average_hours = nil
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

  def looks_like_address?(q)
    # tem números (ex.: "123") OU começa com prefixos comuns
    return true if q =~ /\d/
    q =~ /\b(rua|r\.|avenida|av\.?|alameda|praça|praca|estrada|rod\.?|rodovia)\b/i
  end

  def set_owned_service
    @service = current_user.services.find(params[:id])
  end
end
