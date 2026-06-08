class AddIsBlockToVisualModesUniqueIndex < ActiveRecord::Migration[7.1]
  def change
    remove_index :visual_modes, name: "idx_visual_modes_unique_combo"
    add_index :visual_modes, [:municipality_code, :opportunity_code, :mode_code, :is_block],
              name: "idx_visual_modes_unique_combo",
              unique: true
  end
end
