class NormalizeLocationTypeToSpanish < ActiveRecord::Migration[7.1]
  def up
    execute "UPDATE cell_norms SET location_type = 'urbano' WHERE location_type = 'urban'"
    execute "UPDATE simulation_agent_types SET location_restriction = 'urbano' WHERE location_restriction = 'urban'"
  end

  def down
    execute "UPDATE cell_norms SET location_type = 'urban' WHERE location_type = 'urbano'"
    execute "UPDATE simulation_agent_types SET location_restriction = 'urban' WHERE location_restriction = 'urbano'"
  end
end
