# app/controllers/conversations/messages_controller.rb
module Conversations
  class MessagesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_conversation
    before_action :authorize_participation!

    def create
      @message = @conversation.messages.build(message_params.merge(user: current_user))

      if @message.save
        respond_to do |format|
          format.turbo_stream do
            # ❌ NADA de append aqui!
            # ✅ Só atualiza o form vazio; o append vem do broadcast do modelo.
            render turbo_stream: turbo_stream.update(
              helpers.dom_id(@conversation, :form),
              partial: "messages/form_conversation",
              locals: { conversation: @conversation, message: Message.new }
            )
          end

          format.html { redirect_to conversation_path(@conversation) }
        end
      else
        respond_to do |format|
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              helpers.dom_id(@conversation, :form),
              partial: "messages/form_conversation",
              locals: { conversation: @conversation, message: @message }
            )
          end

          format.html do
            @messages = @conversation.messages.includes(:user).order(:created_at)
            render "conversations/show", status: :unprocessable_entity
          end
        end
      end
    end

    private

    def set_conversation
      @conversation = Conversation.find(params[:conversation_id])
    end

    def authorize_participation!
      allowed = [@conversation.client_id, @conversation.professional_id].include?(current_user.id)
      head :forbidden unless allowed
    end

    def message_params
      params.require(:message).permit(:content)
    end
  end
end
