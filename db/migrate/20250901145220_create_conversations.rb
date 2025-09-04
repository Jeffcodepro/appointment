class CreateConversations < ActiveRecord::Migration[7.1]
  def change
  create_table :conversations do |t|
        t.references :client,       null: false, foreign_key: { to_table: :users }
        t.references :professional, null: false, foreign_key: { to_table: :users }
        t.references :service,      null: false, foreign_key: true
        t.timestamps
      end

      add_index :conversations,
                [:client_id, :professional_id, :service_id],
                unique: true,
                name: "idx_unique_conversation_triplet"
  end
end
