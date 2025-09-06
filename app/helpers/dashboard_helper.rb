module DashboardHelper
  # Gera uma classe determinística por serviço (ou evento) p/ variar cores
  def calendar_color_for(event)
    key = event.try(:service_id) || event.try(:id) || 0
    "gc-c#{key.to_i % 6}" # 6 variações
  end
end
