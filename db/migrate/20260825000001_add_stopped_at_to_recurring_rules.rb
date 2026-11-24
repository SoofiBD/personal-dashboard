class AddStoppedAtToRecurringRules < ActiveRecord::Migration[7.1]
  def change
    add_column :finance_recurring_rules, :stopped_at, :datetime
  end
end
