    class SchedulesController < ApplicationController

      before_action :authenticate_user!, only: [:create, :show]

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

      def show
        @schedule = Schedule.includes(:service, :user, :messages).find(params[:id])
        authorize_participation!(@schedule)

        @messages = @schedule.messages.includes(:user).order(:created_at)
        @message  = Message.new
      end

    private

      def authorize_participation!(schedule)
        is_client      = schedule.user_id == current_user.id
        is_professional= schedule.service.user_id == current_user.id
        return if is_client || is_professional

        redirect_to root_path, alert: "Acesso negado ao chat."
      end
    end
