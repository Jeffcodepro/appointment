class Schedule < ApplicationRecord
  belongs_to :user
  belongs_to :service

  validates :start_at, :end_at, presence: true
  validate  :no_overlap_for_provider

  scope :for_provider, ->(provider_id) { joins(:service).where(services: { user_id: provider_id }) }

  private

  def no_overlap_for_provider
    return if start_at.blank? || end_at.blank?

    overlapping =
      Schedule
        .for_provider(service.user_id)
        .where.not(id: id)
        .where("start_at < ? AND end_at > ?", end_at, start_at)

    errors.add(:base, "Conflito com outro agendamento") if overlapping.exists?
  end
end
