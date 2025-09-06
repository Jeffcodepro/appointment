class DashboardsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_professional!

  include ActionView::Helpers::NumberHelper


  def show
    @user = current_user

    @view = params[:view].presence_in(%w[week month]) || "month"
    @date = safe_date(params[:date])

    if @view == "week"
      @range_start = @date.beginning_of_week(:monday)
      @range_end   = @date.end_of_week(:sunday)
    else
      @range_start = @date.beginning_of_month
      @range_end   = @date.end_of_month
    end

    # ajuste o "base" ao seu caso (profissional logado, etc.)
    base = Schedule
      .includes(:service, :client, :professional)
      .where(professional_id: @user.id)
      .where(start_at: @range_start.beginning_of_day..@range_end.end_of_day)

    @schedules = base.order(:start_at)

    now     = Time.zone.now
    past    = base.where("start_at <  ?", now)
    future  = base.where("start_at >= ?", now)

    @appointments_count        = base.count
    @appointments_past_count   = past.count
    @appointments_future_count = future.count

    @revenue_past   = total_revenue(past)   # Money
    @revenue_future = total_revenue(future) # Money

    @revenue_human        = helpers.humanized_money_with_symbol(@revenue_past)
    @revenue_future_human = helpers.humanized_money_with_symbol(@revenue_future)

    @prev_date = (@view == "week" ? @date - 1.week  : @date - 1.month)
    @next_date = (@view == "week" ? @date + 1.week  : @date + 1.month)
  end


  private

  def require_professional!
    unless current_user&.professional?
      redirect_to root_path, alert: "Somente profissionais podem acessar o painel."
    end
  end

  def safe_date(value)
    return Date.current if value.blank?
    case value
    when Date
      value
    when Time, ActiveSupport::TimeWithZone
      value.to_date
    when String
      Date.iso8601(value) rescue (Date.parse(value) rescue Date.current)
    else
      Date.current
    end
  end


  def total_revenue(scope)
    scope.to_a.reduce(Money.new(0, Money.default_currency || "BRL")) do |sum, s|
      ph = s.service&.price_hour
      if ph.present? && s.start_at && s.end_at
        hours = (s.end_at - s.start_at) / 3600.0
        sum + (ph * hours)
      else
        sum
      end
    end
  end

end
