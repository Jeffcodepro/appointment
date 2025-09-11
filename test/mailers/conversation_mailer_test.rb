require "test_helper"

class ConversationMailerTest < ActionMailer::TestCase
  test "new_message" do
    mail = ConversationMailer.new_message
    assert_equal "New message", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

  test "pending_reminder" do
    mail = ConversationMailer.pending_reminder
    assert_equal "Pending reminder", mail.subject
    assert_equal ["to@example.org"], mail.to
    assert_equal ["from@example.com"], mail.from
    assert_match "Hi", mail.body.encoded
  end

end
