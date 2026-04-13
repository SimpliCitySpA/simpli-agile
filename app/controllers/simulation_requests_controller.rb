class SimulationRequestsController < ApplicationController
  before_action :authenticate_user!

  def create
    scenario = Scenario.find(params[:scenario_id])

    unless scenario.user_id == current_user.id
      return render json: { error: "No autorizado" }, status: :forbidden
    end

    require_municipality_access!(scenario.municipality_code)

    if scenario.status == "base"
      return render json: { error: "No se puede simular en el escenario base" }, status: :unprocessable_entity
    end

    agents = Array(params[:agents]).select { |a| a[:n_agents].to_i > 0 }

    if agents.empty?
      return render json: { error: "Ingresa al menos un agente para simular." }, status: :unprocessable_entity
    end

    requests = agents.map do |agent|
      SimulationRequest.create!(
        scenario_id:     scenario.id,
        agent_type_code: agent[:agent_type_code],
        n_agents:        agent[:n_agents].to_i,
        seed:            params[:seed]
      )
    end

    requests.each { |r| SimulationJob.perform_later(r.id) }

    render json: { ok: true, simulation_request_ids: requests.map(&:id) }, status: :created
  end
end
