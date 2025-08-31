class DashboardsController < ApplicationController
  def show
    @user = current_user
    @services = current_user.services
  end

  def new
    @service = Service.new
  end

  def bookings
    @bookings = Schedule.where(service_user_id: current_user.id)
  end

end
