class ServicesController < ApplicationController
  def index
    @services = Service.all

    if params[:query].present?
      # Usa a busca global definida no modelo Service
      @services = @services.global_search(params[:query])
    end
  end
end
