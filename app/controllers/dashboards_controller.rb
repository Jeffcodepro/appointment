class DashboardsController < ApplicationController
  def show
    @user = current_user
    @services = current_user.services

    if current_user.professional?
      @conversations = Conversation.where(professional: current_user).order(updated_at: :desc)
    else
      @conversations = Conversation.where(client: current_user).order(updated_at: :desc)
    end
  end

  def new
    @service = Service.new
  end

  def bookings
    @bookings = Schedule.where(service_user_id: current_user.id)
  end

end
