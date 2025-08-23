class CreateSchedules < ActiveRecord::Migration[7.1]
  def change
    create_table :schedules do |t|
      t.references :user, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.boolean :accepted_client
      t.boolean :accepted_professional
      t.time :start_time
      t.time :end_time
      t.boolean :confirmed

      t.timestamps
    end
  end
end
