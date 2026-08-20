class CreateDashboardUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :name, null: false
      t.string :currency, null: false, limit: 3, default: "TRY"
      t.string :time_zone, null: false, default: "Europe/Istanbul"
      t.timestamps
    end
  end
end
