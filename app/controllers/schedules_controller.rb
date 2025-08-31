  class SchedulesController < ApplicationController

    before_action :authenticate_user!, only: [:create]

    def create
      service = Service.find(params[:service_id])
      start_at = Time.zone.parse(params[:start_at])
      end_at   = Time.zone.parse(params[:end_at])

      schedule = Schedule.new(
        user: current_user,        # cliente
        service: service,
        start_at: start_at,
        end_at: end_at,
        accepted_client: true,
        accepted_professional: false,
        confirmed: false
      )

      if schedule.save
        redirect_to service_path(service), notice: "Solicitação enviada! Aguarde a confirmação do profissional."
      else
        redirect_to service_path(service), alert: schedule.errors.full_messages.to_sentence
      end
    end
  end

