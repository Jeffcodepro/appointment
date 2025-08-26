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
        info_window_html: render_to_string(partial: "info_window", locals: { service: service }),
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

  def show
    @service = Service.find(params[:id])
  end
end
