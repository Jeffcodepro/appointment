class Conversation < ApplicationRecord
  belongs_to :client,       class_name: "User"
  belongs_to :professional, class_name: "User"
  belongs_to :service

  has_many :messages, dependent: :destroy

  validates :client_id, :professional_id, :service_id, presence: true
  validates :client_id, uniqueness: { scope: [:professional_id, :service_id],
                                      message: "já existe uma conversa com este profissional para este serviço" }
  validate :participants_cannot_be_same

  private

  def participants_cannot_be_same
    errors.add(:base, "Participantes não podem ser o mesmo usuário") if client_id == professional_id
  end
end
