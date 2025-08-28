class ServicesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :cities, :show]
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
      date     = params[:date].present? ? Date.parse(params[:date]) : Date.current

      # janela do dia selecionado (entre 09:00 e 18:00)
      open_h   = 9
      close_h  = 18
      duration = (service.average_hours.presence || 1).hours

      day_start = date.in_time_zone.change(hour: open_h,  min: 0)
      day_end   = date.in_time_zone.change(hour: close_h, min: 0)

      # agendamentos existentes desse provider no dia (confirmados ou não)
      day_schedules = Schedule
        .for_provider(provider.id)
        .where("start_at < ? AND end_at > ?", day_end, day_start)
        .pluck(:start_at, :end_at)

      # gera slots a cada 30min (ajuste)
      step = 30.minutes
      slots = []
      t = day_start
      while (t + duration) <= day_end
        slot_start = t
        slot_end   = t + duration

        # conflito?
        conflict = day_schedules.any? do |(s_start, s_end)|
          s_start < slot_end && s_end > slot_start
        end

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


  def show
    @service   = Service.includes(user: { images_attachments: :blob }).find(params[:id])
    @provider  = @service.user
    @services_from_provider = @provider.services.order(:categories, :subcategories)

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
end
