module Scenarios
  class RecalcAccessibility
    def self.call!(scenario:, opportunity_code:)
      new(scenario:, opportunity_code:).call!
    end

    def initialize(scenario:, opportunity_code:)
      @scenario         = scenario
      @opportunity_code = opportunity_code
    end

    def call!
      conn       = ActiveRecord::Base.connection
      scenario_id = @scenario.id
      mun_code   = @scenario.municipality_code
      category   = Opportunity.find_by(opportunity_code: @opportunity_code)&.category

      is_poi    = category == "POI"
      acc_type  = is_poi ? "units"    : "surface"
      value_col = is_poi ? "units_total" : "surface_total"
      base_col  = is_poi ? "units"    : "surface"
      amplifier = is_poi ? "* 10000"  : ""

      travel_modes = TravelMode.where(municipality_code: mun_code, mode: %w[walk car]).pluck(:id).map(&:to_i)

      travel_modes.each do |tm_id|
        Accessibility.where(
          scenario_id:      scenario_id,
          travel_mode_id:   tm_id,
          opportunity_code: @opportunity_code,
          accessibility_type: acc_type
        ).delete_all

        sql = <<~SQL
          INSERT INTO accessibilities (
            h3, travel_mode_id, opportunity_code, scenario_id, accessibility_type, value
          )
          SELECT
            o.h3,
            tm.id,
            $1,
            s.id,
            '#{acc_type}',
            SUM(
              COALESCE(sc.#{value_col}, ic.#{base_col}, 0) * EXP(tm.param_1 * tt.travel_time)
            ) #{amplifier} AS value
          FROM scenarios s
          JOIN cells o
            ON o.municipality_code = s.municipality_code
          JOIN travel_modes tm
            ON tm.municipality_code = s.municipality_code
           AND tm.id = $2
          JOIN travel_times tt
            ON tt.h3_origin = o.h3
           AND tt.travel_mode_id = tm.id
          JOIN cells d
            ON d.h3 = tt.h3_destiny
          LEFT JOIN scenario_cells sc
            ON sc.scenario_id = s.id
           AND sc.h3 = d.h3
           AND sc.opportunity_code = $1
          LEFT JOIN info_cells ic
            ON ic.h3 = d.h3
           AND ic.opportunity_code = $1
          WHERE s.id = $3
            AND s.municipality_code = $4
            AND d.municipality_code = $4
          GROUP BY o.h3, tm.id, s.id;
        SQL

        conn.raw_connection.exec_params(sql, [@opportunity_code, tm_id, scenario_id, mun_code])
      end
    end
  end
end
