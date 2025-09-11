# app/models/message.rb
class Message < ApplicationRecord
  belongs_to :user
  belongs_to :schedule,     optional: true
  belongs_to :conversation, optional: true
  attr_accessor :skip_email_notifications

  validates :content, presence: true
  validate  :belongs_to_parent

  after_create_commit :broadcast_to_threads

  after_create_commit :email_counterparty

  private

  def email_counterparty
    return if skip_email_notifications

    conv = conversation
    if conv.nil? && schedule_id?
      conv = ensure_conversation_for(schedule)
    end
    return unless conv

    client_id = conv.client_id
    pro_id    = conv.professional_id

    # descobre o papel de quem enviou
    sender_role =
      if user_id == client_id
        :client
      elsif user_id == pro_id
        :professional
      else
        :unknown
      end

    # só notifica o outro lado; nunca o próprio remetente
    recipient_id =
      case sender_role
      when :client       then pro_id
      when :professional then client_id
      else                    nil
      end

    if recipient_id.blank? || recipient_id == user_id
      Rails.logger.warn("[EMAIL_DEBUG] skip: recipient_id=#{recipient_id.inspect} sender_id=#{user_id} conv=#{conv.id}")
      return
    end

    recipient = User.find_by(id: recipient_id)
    if recipient.blank? || recipient.email.blank?
      Rails.logger.warn("[EMAIL_DEBUG] skip: recipient missing/email blank conv=#{conv.id}")
      return
    end

    # throttle (evita bombardeio)
    window = Rails.env.production? ? 15.minutes : 15.seconds
    col    = (recipient_id == client_id) ? :last_email_to_client_at : :last_email_to_professional_at
    last   = conv.send(col) if conv.respond_to?(col)
    if last.present? && last > window.ago
      Rails.logger.info("[EMAIL_DEBUG] throttled: #{col}=#{last} window=#{window.inspect}")
      return
    end

    Rails.logger.info("[EMAIL_DEBUG] deliver new_message from=#{user_id} to=#{recipient.email} conv=#{conv.id}")
    mail = ConversationMailer.with(conversation: conv, message: self, recipient: recipient, sender: user).new_message
    Rails.env.development? ? mail.deliver_now : mail.deliver_later
    conv.update_column(col, Time.current) if conv.has_attribute?(col)
  rescue => e
    Rails.logger.error("[EMAIL_DEBUG] Mail fail Message##{id}: #{e.class} - #{e.message}")
  end


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

  def ensure_conversation_for(sched)
    Conversation.find_or_create_by!(
      client_id:       sched.client_id,
      professional_id: sched.professional_id,
      service_id:      sched.service_id
    )
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    Conversation.find_by(
      client_id:       sched.client_id,
      professional_id: sched.professional_id,
      service_id:      sched.service_id
    )
  end

  def belongs_to_parent
    errors.add(:base, "Mensagem deve pertencer a um agendamento ou a uma conversa") if conversation.nil? && schedule.nil?
  end
end
