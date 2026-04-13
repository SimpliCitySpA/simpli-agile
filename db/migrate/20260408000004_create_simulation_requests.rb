class CreateSimulationRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :simulation_requests do |t|
      t.bigint  :scenario_id,     null: false
      t.string  :agent_type_code, null: false
      t.integer :n_agents,        null: false
      t.string  :status,          default: "pending"  # pending | running | completed | failed
      t.text    :error_message
      t.integer :seed
      t.datetime :started_at
      t.datetime :completed_at
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :simulation_requests, :scenario_id

    add_foreign_key :simulation_requests, :scenarios
  end
end
