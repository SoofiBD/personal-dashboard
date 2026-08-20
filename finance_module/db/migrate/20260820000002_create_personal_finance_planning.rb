class CreatePersonalFinancePlanning < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_budget_periods, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, index: true, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.decimal :planned_income, null: false, precision: 14, scale: 2, default: 0
      t.timestamps
    end
    add_index :finance_budget_periods, %i[user_id starts_on], unique: true

    create_table :finance_budget_allocations, id: :uuid do |t|
      t.references :budget_period, null: false, type: :uuid, foreign_key: { to_table: :finance_budget_periods }
      t.references :category, null: false, type: :uuid, foreign_key: { to_table: :finance_categories }
      t.decimal :planned_amount, null: false, precision: 14, scale: 2, default: 0
      t.timestamps
    end
    add_index :finance_budget_allocations, %i[budget_period_id category_id], unique: true

    create_table :finance_savings_goals, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, index: true, foreign_key: true
      t.string :name, null: false
      t.decimal :target_amount, null: false, precision: 14, scale: 2
      t.date :target_date
      t.decimal :starting_amount, null: false, precision: 14, scale: 2, default: 0
      t.decimal :monthly_contribution, null: false, precision: 14, scale: 2, default: 0
      t.string :status, null: false, default: "active"
      t.timestamps
    end

    create_table :finance_goal_contributions, id: :uuid do |t|
      t.references :savings_goal, null: false, type: :uuid, foreign_key: { to_table: :finance_savings_goals }
      t.references :transaction, type: :uuid, foreign_key: { to_table: :finance_transactions }
      t.decimal :amount, null: false, precision: 14, scale: 2
      t.date :contributed_on, null: false
      t.string :note, limit: 500
      t.timestamps
    end

    create_table :finance_purchase_plans, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, index: true, foreign_key: true
      t.references :savings_goal, type: :uuid, foreign_key: { to_table: :finance_savings_goals }
      t.string :name, null: false
      t.decimal :price, null: false, precision: 14, scale: 2
      t.date :planned_on
      t.decimal :down_payment, null: false, precision: 14, scale: 2, default: 0
      t.decimal :monthly_cost, null: false, precision: 14, scale: 2, default: 0
      t.text :notes
      t.timestamps
    end
  end
end
