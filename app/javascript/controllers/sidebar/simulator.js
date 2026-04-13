// app/javascript/controllers/sidebar/simulator.js

export function createSimulator(controller) {
  return {
    loadAgentTypesIntoPanel() {
      const munCode = controller._selectedMunicipalityCode
      if (!munCode || !controller.hasAgentInputsContainerTarget) return

      fetch(`/simulation_agent_types?municipality_code=${munCode}`, {
        headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content }
      })
        .then(r => r.json())
        .then(data => {
          const container = controller.agentInputsContainerTarget
          container.innerHTML = ""

          if (data.length === 0) {
            container.innerHTML = '<p class="sidebar__no-data-msg">No hay tipos de agente configurados para esta comuna.</p>'
            return
          }

          data.forEach(agentType => {
            const section = document.createElement("div")
            section.className = "sidebar__section"
            section.innerHTML = `
              <div class="sidebar__label">${agentType.name.toUpperCase()}</div>
              <input
                class="sidebar__input"
                type="number"
                min="0"
                step="1"
                inputmode="numeric"
                placeholder="Nº de agentes"
                data-agent-type-code="${agentType.code}"
                data-sidebar-target="agentInput"
              >
            `
            container.appendChild(section)
          })
        })
        .catch(err => console.error("Error cargando tipos de agente:", err))
    },

    toggleSimulator() {
      const opening = controller.simulatorPanelTarget.hidden
      controller.simulatorPanelTarget.hidden = !opening

      if (opening) {
        controller.simulatorPanelTarget.style.left = controller.collapsed ? "0px" : "304px"
        controller.loadAgentTypesIntoPanel()
      }
    },

    async runSimulation() {
      const scenarioId = controller._selectedScenarioId
      if (!scenarioId) return alert("Selecciona un escenario primero.")
      if (controller._selectedScenarioIsBase) return alert("No puedes simular en el escenario base. Crea un escenario propio con el botón '+'.")

      const agents = controller.agentInputTargets
        .map(input => ({
          agent_type_code: input.dataset.agentTypeCode,
          n_agents: Number(input.value) || 0
        }))
        .filter(a => a.n_agents > 0)

      if (agents.length === 0) return alert("Ingresa al menos un agente para simular.")

      const csrf = document.querySelector('meta[name="csrf-token"]').content

      const resp = await fetch("/simulation_requests", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrf },
        body: JSON.stringify({ scenario_id: scenarioId, agents })
      })

      const json = await resp.json()
      if (!resp.ok) {
        return alert(json.error || "Error al iniciar la simulación.")
      }

      controller.agentInputTargets.forEach(input => { input.value = "" })
      alert("Simulación enviada correctamente.")
    }
  }
}
