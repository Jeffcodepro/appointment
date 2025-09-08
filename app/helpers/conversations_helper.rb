module ConversationsHelper
  def conversation_partner_name(conversation, viewer)
    if viewer.id == conversation.client_id
      conversation.professional&.name || "Profissional"
    else
      conversation.client&.name || "Cliente"
    end
  end

  def total_unread_for(user)
    Conversation
      .includes(:messages)
      .where("client_id = :id OR professional_id = :id", id: user.id)
      .sum { |c| c.unread_count_for(user) }
  end
end
