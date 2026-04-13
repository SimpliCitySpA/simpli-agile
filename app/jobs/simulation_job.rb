class SimulationJob < ApplicationJob
  queue_as :default

  def perform(simulation_request_id)
    request = SimulationRequest.find(simulation_request_id)
    return unless request.status.in?(%w[pending running])

    request.update!(status: "running", started_at: Time.current)
    SimulationRunner.new(request).run!
    request.update!(status: "completed", completed_at: Time.current)
  rescue => e
    SimulationRequest.find_by(id: simulation_request_id)
                     &.update!(status: "failed", error_message: e.message, completed_at: Time.current)
    raise
  end
end
