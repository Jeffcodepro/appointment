class Schedule < ApplicationRecord
  belongs_to :user          # cliente
  belongs_to :service       # service.user é o profissional

  validates :start_at, :end_at, presence: true
  validate  :end_after_start
  validate  :no_overlap_for_provider

  # ---- Scopes: sempre no nível da classe ----
  scope :for_provider,     ->(provider_id) { joins(:service).where(services: { user_id: provider_id }) }
  scope :for_professional, ->(pro_user_id) { joins(:service).where(services: { user_id: pro_user_id }) }
  scope :on_day,           ->(date) { where(start_at: date.beginning_of_day..date.end_of_day) }

  # ---- Helpers de instância ----
  def extend_end!(extra_minutes)
    return unless end_at.present?
    update!(end_at: end_at + extra_minutes.to_i.minutes)
  end

  private

  def end_after_start
    return if start_at.blank? || end_at.blank?
    errors.add(:end_at, "deve ser maior que o início") if end_at <= start_at
  end

  def no_overlap_for_provider
    return if start_at.blank? || end_at.blank? || service.blank?

    overlapping = self.class
      .for_provider(service.user_id)         # todos do mesmo profissional (dono do service)
      .where.not(id: id)                     # ignora o próprio
      .where("start_at < ? AND end_at > ?", end_at, start_at) # condição de overlap

    errors.add(:base, "Conflito com outro agendamento") if overlapping.exists?
  end
end
