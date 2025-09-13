# config/initializers/good_job_cron.rb
Rails.application.configure do
  config.good_job.enable_cron = true
  config.good_job.cron = {
    conversation_reminder: {
      cron: "0 */5 * * *", # a cada 5h
      class: "PendingConversationReminderJob",
      description: "Lembra quem ficou sem responder na conversa (5h)."
    },
    schedule_confirmation_reminder: {
      cron: "0 */2 * * *", # a cada 2h
      class: "PendingScheduleConfirmationReminderJob",
      description: "Lembra o profissional de confirmar agendamentos pendentes (2h)."
    }
  }
end
