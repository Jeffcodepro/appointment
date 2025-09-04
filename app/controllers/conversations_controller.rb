class ConversationsController < ApplicationController
  before_action :authenticate_user!

  def index
    service_id = params[:service_id].presence

    @as_professional = Conversation
      .includes(:client, :service, :messages)
      .where(professional_id: current_user.id)
      .yield_self { |rel| service_id ? rel.where(service_id: service_id) : rel }
      .order(updated_at: :desc)

    @as_client = Conversation
      .includes(:professional, :service, :messages)
      .where(client_id: current_user.id)
      .yield_self { |rel| service_id ? rel.where(service_id: service_id) : rel }
      .order(updated_at: :desc)
  end


  def create
    service = Service.find(params[:service_id])
    pro     = service.user

    if current_user.id == pro.id
      redirect_back fallback_location: service_path(service),
                    alert: "Você não pode iniciar uma conversa consigo mesmo." and return
    end

    @conversation = Conversation.find_or_create_by!(
      client: current_user, professional: pro, service: service
    )

    redirect_to conversation_path(@conversation)
  end

  def show
    @conversation = Conversation.find(params[:id])
    authorize_participation!

    @messages = @conversation.messages.includes(:user).order(:created_at)
    @message  = @conversation.messages.build
  end

  private

  def authorize_participation!
    return if [@conversation.client_id, @conversation.professional_id].include?(current_user.id)
    redirect_to root_path, alert: "Acesso negado à conversa."
  end
end
