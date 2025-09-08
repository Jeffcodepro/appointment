class AddLastReadToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :last_read_client_at, :datetime
    add_column :conversations, :last_read_professional_at, :datetime
    add_index  :conversations, :last_read_client_at
    add_index  :conversations, :last_read_professional_at
  end
end
