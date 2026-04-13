module Scenarios
  class Recalculate
    class Error < StandardError; end

    def self.call!(scenario:)
      new(scenario:).call!
    end

    def initialize(scenario:)
      @scenario = scenario
    end

    def call!
      Scenario.transaction do
        parent_id = @scenario.parent_id

        parent_map = build_parent_map(parent_id)

        deltas = build_deltas_from_projects(@scenario.id)

        info_map = build_info_map(deltas)

        deltas.each do |d|
          key = [d[:h3], d[:opportunity_code]]

          # parent_map tiene los totales del escenario padre (si existe y tiene scenario_cells).
          # Si no encuentra la clave (p.ej. el padre es base y solo tiene info_cells),
          # cae al info_map que siempre tiene los valores base reales.
          base_units, base_surface = parent_map.fetch(key) { info_map.fetch(key, [0, 0]) }

          ScenarioCell.upsert(
            {
              scenario_id: @scenario.id,
              h3: d[:h3],
              opportunity_code: d[:opportunity_code],
              units_delta: d[:units_delta],
              surface_delta: d[:surface_delta],
              units_total: base_units + d[:units_delta],
              surface_total: base_surface + d[:surface_delta]
            },
            unique_by: :idx_scenario_cells_unique
          )
        end

        @scenario.update!(status: "published") if @scenario.status == "draft"

        Project.where(scenario_id: @scenario.id).update_all(recalculated: true)

        opp_codes = Project.where(scenario_id: @scenario.id).distinct.pluck(:opportunity_code)
        opp_codes.each do |opp|
          recalc_accessibilities!(scenario: @scenario, opportunity_code: opp)
        end
      end

      @scenario
    end

    private

    def build_info_map(deltas)
      return {} if deltas.empty?

      h3s       = deltas.map { |d| d[:h3] }.uniq
      opp_codes = deltas.map { |d| d[:opportunity_code] }.uniq

      InfoCell.where(h3: h3s, opportunity_code: opp_codes).each_with_object({}) do |ic, map|
        map[[ic.h3, ic.opportunity_code]] = [ic.units.to_i, ic.surface.to_d]
      end
    end

    def build_parent_map(parent_id)
      map = {}
      return map unless parent_id.present?

      ScenarioCell.where(scenario_id: parent_id).find_each do |sc|
        map[[sc.h3, sc.opportunity_code]] = [sc.units_total, sc.surface_total]
      end
      map
    end

    def build_deltas_from_projects(scenario_id)
      Project
        .where(scenario_id:)
        .group(:h3, :opportunity_code)
        .pluck(
          :h3,
          :opportunity_code,
          Arel.sql("SUM(total_agents)"),
          Arel.sql("SUM(total_agents * surface_per_agent)")
        )
        .map do |h3, opp, units_delta, surface_delta|
          {
            h3: h3,
            opportunity_code: opp,
            units_delta: units_delta.to_i,
            surface_delta: surface_delta.to_d
          }
        end
    end

    def recalc_accessibilities!(scenario:, opportunity_code:)
      Scenarios::RecalcAccessibility.call!(scenario:, opportunity_code:)
    end
  end
end
