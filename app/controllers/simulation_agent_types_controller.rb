class SimulationAgentTypesController < ApplicationController
  before_action :verify_data_request!

  def index
    agent_types = SimulationAgentType
      .where(municipality_code: params[:municipality_code])
      .select(:id, :code, :name, :opportunity_code, :location_restriction, :agglomeration_method)
    render json: agent_types
  end
end
