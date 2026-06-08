class Block < ApplicationRecord
  belongs_to :municipality, foreign_key: :municipality_code, primary_key: :municipality_code
  has_many :block_accessibilities, foreign_key: :block_id, primary_key: :block_id
end
