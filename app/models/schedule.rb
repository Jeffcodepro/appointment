class Schedule < ApplicationRecord
  belongs_to :user
  belongs_to :service

  scope :for_professional, ->(pro_user_id) { joins(:service).where(services: { user_id: pro_user_id }) }
  scope :on_day, ->(date) { where(scheduled_on: date) }

  def extend_end!(extra_minutes)
    return unless end_time.present?
    update!(end_time: end_time + extra_minutes.to_i.minutes)
  end
end
