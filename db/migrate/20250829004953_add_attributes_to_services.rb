class AddAttributesToServices < ActiveRecord::Migration[7.1]
  def change
    add_column :services, :category, :string
    add_column :services, :subcategory, :string
  end
end
