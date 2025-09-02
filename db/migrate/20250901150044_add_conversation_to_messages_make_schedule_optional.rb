class AddConversationToMessagesMakeScheduleOptional < ActiveRecord::Migration[7.1]
  def change
    add_reference :messages, :conversation, foreign_key: true, null: true
    change_column_null :messages, :schedule_id, true

    add_check_constraint :messages,
      "(schedule_id IS NOT NULL) OR (conversation_id IS NOT NULL)",
      name: "messages_has_parent"
  end
end
