class AddDefaultTimestampsToBlocks < ActiveRecord::Migration[7.1]
  def change
    change_column_default :blocks, :created_at, -> { 'CURRENT_TIMESTAMP' }
    change_column_default :blocks, :updated_at, -> { 'CURRENT_TIMESTAMP' }
  end
end
