class CreateRateLimitCounters < ActiveRecord::Migration[7.1]
  def change
    create_table :rate_limit_counters do |t|
      t.string :key, null: false
      t.integer :attempts, null: false, default: 0
      t.datetime :expires_at

      t.timestamps
    end

    add_index :rate_limit_counters, :key, unique: true
  end
end
