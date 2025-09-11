require "test_helper"

class ScheduleMailerTest < ActionMailer::TestCase
  test "booking_confirmed_to_client" do
    mail = ScheduleMailer.booking_confirmed_to_client
    assert_equal "Booking confirmed to client", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

end
