class AddPriceToServices < ActiveRecord::Migration[7.1]
  def change
    add_monetize :services, :price_hour, currency: { present: false }
  end
end
