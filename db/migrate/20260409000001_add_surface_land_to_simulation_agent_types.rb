class AddSurfaceLandToSimulationAgentTypes < ActiveRecord::Migration[7.1]
  def change
    add_column :simulation_agent_types, :surface_per_unit_m2, :float
    add_column :simulation_agent_types, :land_per_unit_m2,    :float
  end
end
