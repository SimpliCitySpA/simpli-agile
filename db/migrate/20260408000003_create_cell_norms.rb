class CreateCellNorms < ActiveRecord::Migration[7.1]
  def change
    create_table :cell_norms do |t|
      t.string  :h3,                   null: false
      t.bigint  :norm_scenario_id,     null: false
      t.float   :remanente_efectivo_m2
      t.float   :remanente_huella_m2
      t.string  :location_type         # 'urbano' | 'rural'
      t.timestamps default: -> { "CURRENT_TIMESTAMP" }
    end

    add_index :cell_norms, [:h3, :norm_scenario_id], unique: true, name: "uq_cell_norms"
    add_index :cell_norms, :norm_scenario_id

    add_foreign_key :cell_norms, :cells,     column: :h3,              primary_key: :h3
    add_foreign_key :cell_norms, :scenarios, column: :norm_scenario_id
  end
end
