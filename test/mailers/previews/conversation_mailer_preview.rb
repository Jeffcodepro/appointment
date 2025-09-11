# Preview all emails at http://localhost:3000/rails/mailers/conversation_mailer
class ConversationMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/conversation_mailer/new_message
  def new_message
    ConversationMailer.new_message
  end

  # Preview this email at http://localhost:3000/rails/mailers/conversation_mailer/pending_reminder
  def pending_reminder
    ConversationMailer.pending_reminder
  end

end
