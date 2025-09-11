class PendingConversationReminderJob < ApplicationJob
  queue_as :mailers
  THRESHOLD = 6.hours

  def perform
    Conversation.find_each do |conv|
      last_msg = Message.where(conversation_id: conv.id).order(created_at: :desc).first
      next unless last_msg && last_msg.created_at < THRESHOLD.ago

      remind_side(conv, :client,         conv.last_read_client_at,         conv.last_email_to_client_at)
      remind_side(conv, :professional,   conv.last_read_professional_at,   conv.last_email_to_professional_at)
    end
  end

  private

  def remind_side(conv, role, last_read_at, last_email_at)
    user = role == :client ? User.find_by(id: conv.client_id) : User.find_by(id: conv.professional_id)
    return if user.blank? || user.email.blank?

    last_msg_at = Message.where(conversation_id: conv.id).maximum(:created_at)
    unread = last_read_at.nil? || last_read_at < last_msg_at
    throttled = last_email_at && last_email_at > THRESHOLD.ago
    return unless unread && !throttled

    ConversationMailer
      .with(conversation: conv, recipient: user)
      .pending_reminder
      .deliver_later

    col = role == :client ? :last_email_to_client_at : :last_email_to_professional_at
    conv.update_column(col, Time.current)
  end
end
