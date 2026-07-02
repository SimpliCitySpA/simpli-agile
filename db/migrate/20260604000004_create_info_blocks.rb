class CreateInfoBlocks < ActiveRecord::Migration[7.1]
  def change
    create_table :info_blocks do |t|
      t.integer :block_id, null: false
      t.string :opportunity_code
      t.integer :units
      t.integer :surface

      t.timestamps default: -> { 'CURRENT_TIMESTAMP' }
    end

    add_index :info_blocks, :block_id
    add_index :info_blocks, :opportunity_code

    add_foreign_key :info_blocks, :blocks, column: :block_id, primary_key: :block_id
    add_foreign_key :info_blocks, :opportunities, column: :opportunity_code, primary_key: :opportunity_code
  end
end
