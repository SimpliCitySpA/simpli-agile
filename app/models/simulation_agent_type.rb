class SimulationAgentType < ApplicationRecord
  belongs_to :municipality, foreign_key: :municipality_code, primary_key: :municipality_code
  belongs_to :opportunity, foreign_key: :opportunity_code, primary_key: :opportunity_code
end
