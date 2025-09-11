class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :load_parent!  # Schedule ou Conversation
  before_action :authorize_participation!
  before_action :set_parent

  def create
    message = @parent.messages.build(
      user: current_user,
      content: params.dig(:message, :content).to_s
    )

    if message.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            helpers.dom_id(@parent, :form),
            partial: "messages/composer",
            locals: { parent: @parent, message: Message.new }
          )
        end
        format.html { redirect_to polymorphic_path(@parent) }
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            helpers.dom_id(@parent, :form),
            partial: "messages/composer",
            locals: { parent: @parent, message: message }
          ), status: :unprocessable_entity
        end
        format.html { redirect_to polymorphic_path(@parent), alert: message.errors.full_messages.to_sentence }
      end
    end
  end

  private

  # --- parent: Schedule OU Conversation ---
  def load_parent!
    if params[:schedule_id].present?
      @parent = Schedule.includes(:client, :professional, :service).find(params[:schedule_id])
    elsif params[:conversation_id].present?
      @parent = Conversation.includes(:client, :professional, :service).find(params[:conversation_id])
    else
      head :bad_request
    end
  end

  def set_parent
    if params[:conversation_id].present?
      @parent = Conversation.find(params[:conversation_id])
    elsif params[:schedule_id].present?
      @parent = Schedule.find(params[:schedule_id])
    else
      head :unprocessable_entity
    end
  end

  # --- autorização para ambos os tipos ---
  def authorize_participation!
    case @parent
    when Schedule
      allowed = [@parent.client_id, @parent.professional_id, @parent.service&.user_id].compact
      head :forbidden unless current_user && allowed.include?(current_user.id)
    when Conversation
      allowed = [@parent.client_id, @parent.professional_id].compact
      head :forbidden unless current_user && allowed.include?(current_user.id)
    else
      head :forbidden
    end
  end
end
