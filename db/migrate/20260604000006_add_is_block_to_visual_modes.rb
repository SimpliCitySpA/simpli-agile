class AddIsBlockToVisualModes < ActiveRecord::Migration[7.1]
  def change
    add_column :visual_modes, :is_block, :boolean, null: false, default: false
  end
end
