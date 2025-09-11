# Preview all emails at http://localhost:3000/rails/mailers/schedule_mailer
class ScheduleMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/schedule_mailer/booking_confirmed_to_client
  def booking_confirmed_to_client
    ScheduleMailer.booking_confirmed_to_client
  end

end
