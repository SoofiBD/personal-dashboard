# frozen_string_literal: true

class HardenAiActionStorage < ActiveRecord::Migration[7.2]
  def change
    add_index :ai_actions, [:user_id, :status, :expires_at, :created_at], name: "index_ai_actions_pending_lookup"
    add_check_constraint :ai_actions,
      "status IN ('pending', 'approved', 'rejected', 'executed', 'failed', 'expired')",
      name: "ai_actions_status_valid"
    add_check_constraint :gym_body_metrics, "weight_kg > 20 AND weight_kg <= 500", name: "gym_body_metrics_weight_range"
  end
end
