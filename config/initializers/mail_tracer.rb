# Só em desenvolvimento
if Rails.env.development?
  filter = ->(mailer, action) { mailer == "ConversationMailer" && action == "new_message" }

  ActiveSupport::Notifications.subscribe("enqueue.action_mailer") do |*args|
    ev = ActiveSupport::Notifications::Event.new(*args)
    next unless filter.(ev.payload[:mailer], ev.payload[:action])
    Rails.logger.warn("[TRACE_MAIL] enqueue #{ev.payload[:mailer]}##{ev.payload[:action]}\n" \
                      "#{caller.select { _1.include?('/app/') }.first(12).join("\n")}")
  end

  ActiveSupport::Notifications.subscribe("deliver.action_mailer") do |*args|
    ev = ActiveSupport::Notifications::Event.new(*args)
    next unless filter.(ev.payload[:mailer], ev.payload[:action])
    Rails.logger.warn("[TRACE_MAIL] deliver #{ev.payload[:mailer]}##{ev.payload[:action]}\n" \
                      "#{caller.select { _1.include?('/app/') }.first(12).join("\n")}")
  end
end
