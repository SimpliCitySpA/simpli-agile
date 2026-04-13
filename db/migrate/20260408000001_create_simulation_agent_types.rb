class CreateSimulationAgentTypes < ActiveRecord::Migration[7.1]
  def change
    create_table :simulation_agent_types do |t|
      t.integer :municipality_code, null: false
      t.string  :code,             null: false
      t.string  :name,             null: false
      t.string  :opportunity_code, null: false
      t.string  :location_restriction   # 'urbano' | 'rural' | 'ambos'
      t.string  :agglomeration_method   # 'bien_comun' | 'hibrido' | 'individual'
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :simulation_agent_types, [:municipality_code, :code], unique: true, name: "uq_agent_types"

    add_foreign_key :simulation_agent_types, :municipalities, column: :municipality_code, primary_key: :municipality_code
    add_foreign_key :simulation_agent_types, :opportunities,  column: :opportunity_code,  primary_key: :opportunity_code
  end
end
