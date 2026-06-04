class CreateBlocks < ActiveRecord::Migration[7.1]
  def change
    create_table :blocks do |t|
      t.integer :show_id
      t.integer :municipality_code, null: false
      t.geometry :geometry, srid: 4326

      t.timestamps
    end

    add_index :blocks, :municipality_code
    add_index :blocks, :geometry, using: :gist
    add_foreign_key :blocks, :municipalities, column: :municipality_code, primary_key: :municipality_code
  end
end
