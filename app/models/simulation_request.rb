class SimulationRequest < ApplicationRecord
  belongs_to :scenario

  STATUSES = %w[pending running completed failed].freeze
  validates :status, inclusion: { in: STATUSES }
  validates :n_agents, numericality: { greater_than: 0 }
end
