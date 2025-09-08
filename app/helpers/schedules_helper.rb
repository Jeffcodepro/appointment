module SchedulesHelper
  def status_pill_class(status)
    case status.to_s
    when "completed" then "is-completed"
    when "canceled"  then "is-canceled"
    when "no_show"   then "is-no-show"
    when "confirmed" then "is-confirmed"
    when "rejected"  then "is-rejected"
    else                 "is-pending"
    end
  end

  def status_label(status)
    {
      "completed" => "Concluído",
      "canceled"  => "Cancelado",
      "no_show"   => "No-show",
      "confirmed" => "Confirmado",
      "pending"   => "Pendente",
      "rejected"  => "Recusado"
    }[status.to_s] || status.to_s.humanize
  end

  def schedule_price(schedule)
    if schedule.respond_to?(:price_cents) && schedule.price_cents.present?
      number_to_currency(schedule.price_cents / 100.0, unit: "R$ ", separator: ",", delimiter: ".")
    elsif schedule.respond_to?(:price) && schedule.price.present?
      number_to_currency(schedule.price, unit: "R$ ", separator: ",", delimiter: ".")
    end
  end

  # === Novos helpers (accordion) ===
  def schedule_duration_minutes(schedule)
    return 0 unless schedule.start_at && schedule.end_at
    ((schedule.end_at - schedule.start_at) / 60).round
  end

  def schedule_duration_human(schedule)
    mins = schedule_duration_minutes(schedule)
    h = mins / 60
    m = mins % 60
    parts = []
    parts << "#{h}h" if h > 0
    parts << "#{m}min" if m > 0
    parts.empty? ? "0min" : parts.join(" ")
  end

  def service_hour_price_numeric(schedule)
    s = schedule.service
    return 0 unless s
    if s.respond_to?(:price_hour_cents) && s.price_hour_cents.present?
      s.price_hour_cents / 100.0
    else
      s.price_hour.to_f
    end
  end

  def service_hour_price_currency(schedule)
    number_to_currency(service_hour_price_numeric(schedule), unit: "R$ ", separator: ",", delimiter: ".")
  end

  def schedule_total_price(schedule)
    hours = schedule_duration_minutes(schedule) / 60.0
    total = hours * service_hour_price_numeric(schedule)
    number_to_currency(total, unit: "R$ ", separator: ",", delimiter: ".")
  end

  # ✅ Mostra “DD/MM/AAAA — HH:MM–HH:MM” (mesmo dia) ou
  #    “DD/MM/AAAA HH:MM – DD/MM/AAAA HH:MM” (dias diferentes)
  def schedule_time_range_compact(schedule)
    s = schedule.start_at
    e = schedule.end_at
    return "-" unless s

    if e && s.to_date == e.to_date
      "#{s.strftime('%d/%m/%Y')} — #{s.strftime('%H:%M')}–#{e.strftime('%H:%M')}"
    else
      end_str = e ? e.strftime('%d/%m/%Y %H:%M') : ""
      "#{s.strftime('%d/%m/%Y %H:%M')} – #{end_str}"
    end
  end

  def status_chip_class(status)
    case status.to_s
    when "pending"    then "is-pending"
    when "confirmed"  then "is-confirmed"
    when "completed"  then "is-completed"
    when "canceled"   then "is-canceled"
    when "no_show"    then "is-no-show"
    when "rejected"   then "is-rejected"
    else "is-default"
    end
  end

  def status_label_with_canceled_by(schedule)
    base = status_label(schedule.status)
    return base unless schedule.canceled?

    who =
      case schedule.canceled_by&.to_s
      when "professional" then "profissional"
      when "client"       then "cliente"
      else nil
      end

    who.present? ? "#{base} <small>(pelo #{who})</small>".html_safe : base
  end

  def canceled_by_label(schedule)
    return unless schedule.respond_to?(:canceled?) && schedule.canceled?
    who = if schedule.canceled_by_client? then "cliente"
          elsif schedule.canceled_by_professional? then "profissional"
          end
    who ? "Cancelado (#{who})" : "Cancelado"
  end
end
