class CellNorm < ApplicationRecord
  belongs_to :cell,     foreign_key: "h3",              primary_key: "h3"
  belongs_to :scenario, foreign_key: "norm_scenario_id"
end
