class CreateTransactions < ActiveRecord::Migration[6.1]
  def change
    create_table :transactions do |t|
      t.decimal :amount
      t.decimal :quantity
      t.integer :type_action

      t.timestamps
    end
  end
end
