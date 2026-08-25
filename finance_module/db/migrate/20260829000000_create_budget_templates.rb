class CreateBudgetTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :finance_budget_templates, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, foreign_key: true
      t.string :name, null: false
      t.jsonb :allocation_data, null: false, default: []
      t.boolean :predefined, null: false, default: false
      t.timestamps
    end

    add_index :finance_budget_templates, %i[user_id name], unique: true
  end
end
