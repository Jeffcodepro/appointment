class AddCanceledByToSchedules < ActiveRecord::Migration[7.1]
  def change
    add_column :schedules, :canceled_by, :integer
    add_index  :schedules, :canceled_by
  end
end
