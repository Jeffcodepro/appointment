class ReplaceTimeWithDatetimeInSchedules < ActiveRecord::Migration[7.1]
  def change
    add_column :schedules, :start_at, :datetime
    add_column :schedules, :end_at,   :datetime
  end
end
