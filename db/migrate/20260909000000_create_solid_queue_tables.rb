class CreateSolidQueueTables < ActiveRecord::Migration[7.2]
  TABLES = %w[
    solid_queue_blocked_executions solid_queue_claimed_executions solid_queue_failed_executions
    solid_queue_jobs solid_queue_pauses solid_queue_processes solid_queue_ready_executions
    solid_queue_recurring_executions solid_queue_recurring_tasks solid_queue_scheduled_executions
    solid_queue_semaphores solid_queue_batches solid_queue_batch_executions
  ].freeze

  def up
    load Rails.root.join("db/queue_schema.rb")
  end

  def down
    TABLES.reverse_each { |table| drop_table table, if_exists: true }
  end
end
