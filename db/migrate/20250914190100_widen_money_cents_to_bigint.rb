class WidenMoneyCentsToBigint < ActiveRecord::Migration[7.1]
  def change
    change_column :services, :price_hour_cents, :bigint, null: false, default: 0
    change_column :service_subcategories, :price_hour_cents, :bigint
  end
end
