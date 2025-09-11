class AddEmailThrottleToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :last_email_to_client_at, :datetime
    add_column :conversations, :last_email_to_professional_at, :datetime
  end
end
