class AddTransferLedgerToTransactions < ActiveRecord::Migration[7.2]
  def change
    add_column :finance_transactions, :transfer_group_id, :uuid
    add_column :finance_transactions, :transfer_direction, :string
    add_index :finance_transactions, :transfer_group_id
  end
end
