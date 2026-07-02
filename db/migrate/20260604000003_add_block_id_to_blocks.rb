class AddBlockIdToBlocks < ActiveRecord::Migration[7.1]
  def change
    add_column :blocks, :block_id, :integer, null: false

    add_index :blocks, :block_id, unique: true
  end
end
