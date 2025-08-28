class RenameMeanHoursToAverageHoursInServices < ActiveRecord::Migration[7.1]
  def change
    rename_column :services, :mean_hours, :average_hours
  end
end
