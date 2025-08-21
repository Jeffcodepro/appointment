class AddRoleAndProfileCompletedToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :role, :integer, null: false, default: 0
    add_column :users, :profile_completed, :boolean, null: false, default: false
    add_index :users, :role
  end
end
