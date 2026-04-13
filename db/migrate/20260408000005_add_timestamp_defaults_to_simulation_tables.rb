class AddTimestampDefaultsToSimulationTables < ActiveRecord::Migration[7.1]
  TABLES = %i[simulation_agent_types model_parameters cell_norms simulation_requests].freeze

  def up
    TABLES.each do |table|
      change_column_default table, :created_at, -> { "CURRENT_TIMESTAMP" }
      change_column_default table, :updated_at, -> { "CURRENT_TIMESTAMP" }
    end
  end

  def down
    TABLES.each do |table|
      change_column_default table, :created_at, nil
      change_column_default table, :updated_at, nil
    end
  end
end
