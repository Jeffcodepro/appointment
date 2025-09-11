class ConversationMailer < ApplicationMailer

  def new_message
    @conversation = params[:conversation]
    @message      = params[:message]
    @recipient    = params[:recipient]
    @sender       = params[:sender]

    mail(
      to: @recipient.email,
      subject: "#{@sender.name || 'Usuário'} te enviou uma nova mensagem no Appointment"
    )
  end

  def pending_reminder
    @conversation = params[:conversation]
    @recipient    = params[:recipient]

    mail(
      to: @recipient.email,
      subject: "Você tem uma conversa pendente no Appointment"
    )
  end
end
