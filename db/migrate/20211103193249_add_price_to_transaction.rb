class AddPriceToTransaction < ActiveRecord::Migration[6.1]
  def change
    add_column :transactions, :price, :decimal
  end
end
