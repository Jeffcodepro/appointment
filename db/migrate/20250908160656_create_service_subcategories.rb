class CreateServiceSubcategories < ActiveRecord::Migration[7.1]
  def change
    create_table :service_subcategories do |t|
      t.references :service, null: false, foreign_key: true
      t.string  :name, null: false
      t.text    :description
      t.integer :price_hour_cents
      t.string  :price_hour_currency, null: false, default: "BRL"
      t.integer :average_hours

      t.timestamps
    end

    add_index :service_subcategories, [:service_id, :name]
  end
end
