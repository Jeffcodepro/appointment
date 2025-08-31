class Schedule < ApplicationRecord
  belongs_to :user        # cliente
  belongs_to :service     # contém o profissional via service.user

  validates :start_at, :end_at, presence: true
  validate  :ends_after_start
  validate  :no_overlap

  scope :for_provider, ->(pro_user_id) {
    joins(:service).where(services: { user_id: pro_user_id })
  }

  scope :on_day, ->(date) {
    start_range = date.beginning_of_day
    end_range   = date.end_of_day
    where("start_at < ? AND end_at > ?", end_range, start_range)
  }

  def start_time
    start_at
  end

  def end_time
    end_at
  end

  private

  def ends_after_start
    return if start_at.blank? || end_at.blank?
    errors.add(:end_at, "deve ser depois do início") if end_at <= start_at
  end

  def no_overlap
    return if start_at.blank? || end_at.blank? || service.nil?

    overlapping = Schedule
      .for_provider(service.user_id)
      .where.not(id: id)
      .where("start_at < ? AND end_at > ?", end_at, start_at)

    errors.add(:base, "Conflito com outro agendamento") if overlapping.exists?
  end

  def extend_end!(extra_minutes)
    return unless end_time.present? update!(end_time: end_time + extra_minutes.to_i.minutes)
  end
end
