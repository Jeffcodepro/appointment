class Schedule < ApplicationRecord
  belongs_to :service
  belongs_to :client,       class_name: "User", foreign_key: :client_id
  belongs_to :professional, class_name: "User", foreign_key: :professional_id
  has_many   :messages, dependent: :destroy

  validates :start_at, :end_at, presence: true
  validate  :ends_after_start
  validate  :no_overlap

  enum status: { pending: 0, confirmed: 1, completed: 2, canceled: 3, no_show: 4 }

  # ---- Scopes: sempre no nível da classe ----
  scope :for_provider,     ->(provider_id) { joins(:service).where(services: { user_id: provider_id }) }
  scope :for_professional, ->(pro_user_id) { joins(:service).where(services: { user_id: pro_user_id }) }
  scope :on_day,           ->(date) { where(start_at: date.beginning_of_day..date.end_of_day) }
  scope :closed, -> { where(status: %i[completed canceled no_show]) }
  scope :past,   -> { where("end_at < ?", Time.current) }
  scope :past_or_closed, -> {
    where("end_at < :now OR status IN (:closed)",
      now: Time.current,
      closed: statuses.slice("completed","canceled","no_show").values
    )
  }

  def start_time
    start_at
  end

  def end_time
    end_at
  end

  # ---- Helpers de instância ----
  def extend_end!(extra_minutes)
    return unless end_at.present?
    update!(end_at: end_at + extra_minutes.to_i.minutes)
  end

  private

  def ends_after_start
    return if start_at.blank? || end_at.blank?
    errors.add(:end_at, "deve ser depois do início") if end_at <= start_at
  end

  def no_overlap
    return if start_at.blank? || end_at.blank? || service.nil?

    overlapping = self.class
      .for_provider(service.user_id)
      .where.not(id: id)
      .where("start_at < ? AND end_at > ?", end_at, start_at)

    errors.add(:base, "Conflito com outro agendamento") if overlapping.exists?
  end
end
