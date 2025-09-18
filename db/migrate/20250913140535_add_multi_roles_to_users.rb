
class AddMultiRolesToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :as_client,       :boolean, null: false, default: true
    add_column :users, :as_professional, :boolean, null: false, default: false
    add_column :users, :active_role,     :string,  null: false, default: "client"

    # Backfill a partir do enum :role existente (0=client, 1=professional)
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE users
             SET as_professional = CASE WHEN role = 1 THEN TRUE ELSE as_professional END,
                 active_role     = CASE WHEN role IN (0,1)
                                          THEN CASE WHEN role = 1 THEN 'professional' ELSE 'client' END
                                          ELSE active_role
                                   END;
        SQL
      end
    end

    # Restringe os valores possíveis
    add_check_constraint :users, "active_role IN ('client','professional')", name: "users_active_role_check"
    add_index :users, :active_role
  end
end
