class CreateServices < ActiveRecord::Migration[7.1]
  def change
    create_table :services do |t|
      t.string :name
      t.text :description
      t.string :categories
      t.string :subcategories
      t.decimal :price_hour
      t.integer :mean_hours
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
