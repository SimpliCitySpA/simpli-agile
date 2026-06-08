class BlockAccessibility < ApplicationRecord
  belongs_to :block, foreign_key: :block_id, primary_key: :block_id
  belongs_to :opportunity, foreign_key: :opportunity_code, primary_key: :opportunity_code
end
