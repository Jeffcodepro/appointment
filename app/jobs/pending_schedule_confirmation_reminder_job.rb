class PendingScheduleConfirmationReminderJob < ApplicationJob
  queue_as :mailers
  THRESHOLD = 2.hours

  def perform
    Schedule.pending
            .includes(:service, :client, :professional)
            .where("start_at > ?", Time.current)      # só futuros
            .where("updated_at < ?", THRESHOLD.ago)   # não mexeu recentemente
            .find_each do |schedule|

      pro = schedule.professional
      next if pro.blank? || pro.email.blank?

      ScheduleMailer.with(schedule: schedule).confirmation_reminder_to_professional.deliver_later
    end
  end
end
