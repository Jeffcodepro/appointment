# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :user
  belongs_to :schedule,     optional: true
  belongs_to :conversation, optional: true

  validates :content, presence: true
  validate  :belongs_to_parent

  after_create_commit :broadcast_to_threads

  private

  def broadcast_to_threads
    if conversation_id?
      # envia para a conversa (comportamento atual)
      broadcast_to_conversation(conversation)

      # espelha no agendamento correspondente (se existir)
      if (sched = mirror_schedule_for(conversation))
        broadcast_to_schedule(sched)
      end

    elsif schedule_id?
      # envia para o agendamento (comportamento atual)
      broadcast_to_schedule(schedule)

      # espelha na conversa correspondente (se existir)
      if (conv = mirror_conversation_for(schedule))
        broadcast_to_conversation(conv)
      end
    end
  end

  # ------- helpers -------

  def broadcast_to_conversation(conv)
    broadcast_append_to [conv, :messages],
      target:  "messages_for_conversation_#{conv.id}",
      partial: "messages/message",
      locals: {
        message: self,
        participants: { client_id: conv.client_id, professional_id: conv.professional_id }
      }
  end

  def broadcast_to_schedule(sched)
    broadcast_append_to [sched, :messages],
      target:  "messages_for_schedule_#{sched.id}",
      partial: "messages/message",
      locals: {
        message: self,
        participants: { client_id: sched.client_id, professional_id: sched.professional_id }
      }
  end

  # Encontra o "par" com base (cliente, profissional, serviço).
  # Se você tiver uma coluna de ligação (ex.: schedules.conversation_id), troque para usá-la.
  def mirror_schedule_for(conv)
    Schedule.where(
      client_id: conv.client_id,
      professional_id: conv.professional_id,
      service_id: conv.service_id
    ).order(start_at: :desc).first
  end

  def mirror_conversation_for(sched)
    Conversation.find_by(
      client_id: sched.client_id,
      professional_id: sched.professional_id,
      service_id: sched.service_id
    )
  end

  def belongs_to_parent
    errors.add(:base, "Mensagem deve pertencer a um agendamento ou a uma conversa") if conversation.nil? && schedule.nil?
  end
end
