class ServicesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :cities, :show, :availability, :calendar, :availability_summary]

  include ActionView::Helpers::NumberHelper

  BRAZIL_BOUNDING_BOX = {
    min_lat: -34.0, max_lat: 5.5,
    min_lng: -74.0, max_lng: -34.5
  }

  def index
    @states = User.where.not(state: [nil, '']).distinct.pluck(:state).sort

    # Base scope já com eager loading de imagens do user e join de users
    @services = Service
                  .includes(user: { images_attachments: :blob }) # evita N+1 nas imagens
                  .joins(:user)

    # Busca textual
    if params[:service_id].present?
      @services = @services.where(id: params[:service_id])
    else
      # busca textual
      if params[:query].present?
        searched_ids = Service.global_search(params[:query]).select(:id)
        @services = @services.where(id: searched_ids)
      end
    end

    # Filtro por categoria
    @services = @services.where(categories: params[:category]) if params[:category].present?

    # Filtros em users
    @services = @services.where(users: { state: params[:state] }) if params[:state].present?
    @services = @services.where(users: { city:  params[:city]  }) if params[:city].present?

    # Bounding box + coords válidas
    @services = @services
                  .where.not(users: { latitude: [nil, 0], longitude: [nil, 0] })
                  .where(users: {
                    latitude:  BRAZIL_BOUNDING_BOX[:min_lat]..BRAZIL_BOUNDING_BOX[:max_lat],
                    longitude: BRAZIL_BOUNDING_BOX[:min_lng]..BRAZIL_BOUNDING_BOX[:max_lng]
                  })
                  .distinct

    # Markers do mapa
    @markers = @services.map do |service|
      {
        lat: service.user.latitude,
        lng: service.user.longitude,
        name: service.user.name,
        service_id: service.id,
        price: service.price_hour.format,
        url: service_path(service),
      }
    end
  end

  def cities
    cities =
      if params[:state].present?
        User.where(state: params[:state])
      else
        User.all
      end
      .where.not(city: [nil, ''])
      .distinct
      .order(:city)
      .pluck(:city)

    render json: cities
  end

  def availability
    service  = Service.find(params[:id])
    provider = service.user

    # parse seguro
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

    day_schedules = Schedule
      .for_provider(provider.id)
      .where("start_at < ? AND end_at > ?", day_end, day_start)
      .pluck(:start_at, :end_at)

    slots = []
    t = day_start
    while (t + duration) <= day_end
      slot_start = t
      slot_end   = t + duration

      conflict = day_schedules.any? { |(s_start, s_end)| s_start < slot_end && s_end > slot_start }

      slots << {
        start_at: slot_start.iso8601,
        end_at:   slot_end.iso8601,
        label:    "#{I18n.l(slot_start, format: :short, default: slot_start.strftime('%d/%m %H:%M'))} – " \
                  "#{I18n.l(slot_end,   format: :time,  default: slot_end.strftime('%H:%M'))}",
        available: !conflict
      }

      t += duration
    end

    render json: { date: date.to_s, slots: slots }
  end



  def calendar
    @service   = Service.find(params[:id])
    @provider  = @service.user
    @provider_schedules = Schedule.for_provider(@provider.id)
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current
    render partial: "services/calendar", locals: { start_date: @start_date }
  end


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
  end

  def availability_summary
    service   = Service.find(params[:id])
    provider  = service.user

    start_date = params[:start].present? ? Date.iso8601(params[:start]) : Date.current.beginning_of_month
    end_date   = params[:end].present?   ? Date.iso8601(params[:end])   : start_date.end_of_month

    # janelas de trabalho (ajuste se tiver config por profissional)
    open_h  = 9
    close_h = 18
    avg_h   = [service.average_hours.to_i, 1].max
    duration = avg_h.hours

    range_start = start_date.in_time_zone.change(hour: open_h,  min: 0)
    range_end   = end_date.in_time_zone.change(  hour: close_h, min: 0)

    # puxa tudo de uma vez e filtra em memória por dia
    all_sched = Schedule
                  .for_provider(provider.id)
                  .where("start_at < ? AND end_at > ?", range_end, range_start)
                  .pluck(:start_at, :end_at)

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
        conflict = day_sched.any? { |s_start, s_end| s_start < slot_end && s_end > slot_start }
        unless conflict
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

end
