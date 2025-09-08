class Conversation < ApplicationRecord
  belongs_to :client,       class_name: "User"
  belongs_to :professional, class_name: "User"
  belongs_to :service

  has_many :messages, dependent: :destroy

  validates :client_id, :professional_id, :service_id, presence: true
  validates :client_id, uniqueness: { scope: [:professional_id, :service_id],
                                      message: "já existe uma conversa com este profissional para este serviço" }
  validate :participants_cannot_be_same

  # ===== Unread helpers =====
  def last_read_at_for(user)
    return last_read_client_at        if user.id == client_id
    return last_read_professional_at  if user.id == professional_id
    nil
  end

  def mark_read_for!(user, time = Time.current)
    if user.id == client_id
      update_column(:last_read_client_at, time)
    elsif user.id == professional_id
      update_column(:last_read_professional_at, time)
    end
  end

  def unread_count_for(user)
    cutoff = last_read_at_for(user)
    scope  = messages.where.not(user_id: user.id) # só conta mensagens do outro participante
    cutoff.present? ? scope.where("created_at > ?", cutoff).count : scope.count
  end

  private

  def participants_cannot_be_same
    errors.add(:base, "Participantes não podem ser o mesmo usuário") if client_id == professional_id
  end
end
