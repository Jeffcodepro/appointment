class Message < ApplicationRecord
  belongs_to :user
  belongs_to :schedule,     optional: true
  belongs_to :conversation, optional: true

  validates :content, presence: true
  validate  :belongs_to_parent

  after_create_commit do
    if conversation_id?
      conversation.touch
      broadcast_append_to [conversation, :messages],
        target:  "messages_for_conversation_#{conversation_id}",
        partial: "messages/message",
        locals: {
          message: self,
          participants: {
            client_id: conversation.client_id,
            professional_id: conversation.professional_id
          }
        }
    elsif schedule_id?
      broadcast_append_to [schedule, :messages],
        target:  "messages_for_schedule_#{schedule_id}",
        partial: "messages/message",
        locals: {
          message: self,
          participants: {
            client_id: schedule.user_id,
            professional_id: schedule.service.user_id
          }
        }
    end
  end

  private

  def belongs_to_parent
    if conversation.nil? && schedule.nil?
      errors.add(:base, "Mensagem deve pertencer a um agendamento ou a uma conversa")
    end
  end
end
