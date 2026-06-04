class CreateBlockAccessibilities < ActiveRecord::Migration[7.1]
  def change
    create_table :block_accessibilities do |t|
      t.integer :block_id, null: false
      t.string :travel_mode, null: false
      t.string :opportunity_code, null: false
      t.string :accessibility_type
      t.float :value

      t.timestamps default: -> { 'CURRENT_TIMESTAMP' }
    end

    add_index :block_accessibilities, :block_id
    add_index :block_accessibilities, :opportunity_code

    add_foreign_key :block_accessibilities, :blocks, column: :block_id, primary_key: :block_id
    add_foreign_key :block_accessibilities, :opportunities, column: :opportunity_code, primary_key: :opportunity_code
  end
end
