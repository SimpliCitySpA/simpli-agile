class SimulationRunner
  # Opportunity codes that restrict by built surface (remanente_efectivo_m2)
  SURFACE_OPP_CODES = %w[HC HD].freeze
  # Opportunity codes that restrict by land footprint (remanente_huella_m2)
  HUELLA_OPP_CODES  = %w[P].freeze

  def initialize(request)
    @request  = request
    @scenario = request.scenario
    @mun_code = @scenario.municipality_code
  end

  def run!
    load_config!

    @cells_cap   = build_cells_capacity
    @cells_acc   = load_accessibility_hash
    @pre_sim     = load_pre_sim_state
    @parent_base = build_parent_base

    # All placements accumulate throughout: {h3 => {units: Int, surface: Float}}
    @placements = Hash.new { |h, k| h[k] = { units: 0, surface: 0.0 } }

    n_agents    = @request.n_agents
    update_freq = 50
    rng         = Random.new(@request.seed || rand(100_000))

    n_agents.times do |i|
      valid_h3s = @cells_cap.filter_map do |h3, cap|
        h3 if capacity_ok?(cap) && location_ok?(cap[:location_type])
      end
      next if valid_h3s.empty?

      chosen_h3 = sample_cell(valid_h3s, rng)

      deduct_capacity!(chosen_h3)
      @placements[chosen_h3][:units]   += 1
      @placements[chosen_h3][:surface] += @surface_per_unit

      # Mid-simulation accessibility recalculation
      if (i + 1) % update_freq == 0 && (i + 1) < n_agents
        write_placements!
        Scenarios::RecalcAccessibility.call!(scenario: @scenario, opportunity_code: @opp_code)
        @cells_acc = load_accessibility_hash
      end
    end

    write_placements!
    Scenarios::RecalcAccessibility.call!(scenario: @scenario, opportunity_code: @opp_code)
  end

  private

  # ── Config loading ────────────────────────────────────────────────────────────

  def load_config!
    agent_type = SimulationAgentType.find_by!(
      municipality_code: @mun_code,
      code:              @request.agent_type_code
    )
    mnl = ModelParameter.find_by!(
      municipality_code: @mun_code,
      agent_type_code:   @request.agent_type_code
    )

    @opp_code         = agent_type.opportunity_code
    @surface_per_unit = agent_type.surface_per_unit_m2.to_f
    @land_per_unit    = agent_type.land_per_unit_m2.to_f
    @location_filter  = agent_type.location_restriction  # 'urbano' | 'rural' | 'ambos'

    @mnl_coeffs = parse_json(mnl.coefficients).transform_keys(&:to_s)
    @mnl_vars   = Array(parse_json(mnl.variables)).map(&:to_s)
  end

  # ── Capacity helpers ──────────────────────────────────────────────────────────

  def capacity_ok?(cap)
    if HUELLA_OPP_CODES.include?(@opp_code)
      cap[:huella] >= @land_per_unit
    else
      # HC, HD and any other: restrict by built surface
      cap[:efectivo] >= @surface_per_unit
    end
  end

  def deduct_capacity!(h3)
    if HUELLA_OPP_CODES.include?(@opp_code)
      @cells_cap[h3][:huella] -= @land_per_unit
    else
      @cells_cap[h3][:efectivo] -= @surface_per_unit
    end
  end

  # ── Data loading ──────────────────────────────────────────────────────────────

  def build_cells_capacity
    norm_scenario_id = Scenario.where(municipality_code: @mun_code, status: "base").pick(:id)

    # Surface already consumed in this working scenario (all opp_codes combined)
    used_surface = ScenarioCell
      .where(scenario_id: @scenario.id)
      .group(:h3)
      .sum(:surface_delta)

    CellNorm.where(norm_scenario_id:).each_with_object({}) do |norm, h|
      h[norm.h3] = {
        efectivo:      [norm.remanente_efectivo_m2.to_f - used_surface[norm.h3].to_f, 0.0].max,
        huella:        norm.remanente_huella_m2.to_f,
        location_type: norm.location_type
      }
    end
  end

  def load_pre_sim_state
    ScenarioCell
      .where(scenario_id: @scenario.id, opportunity_code: @opp_code)
      .index_by(&:h3)
  end

  def build_parent_base
    map = {}

    if @scenario.parent_id
      ScenarioCell
        .where(scenario_id: @scenario.parent_id, opportunity_code: @opp_code)
        .find_each { |sc| map[[sc.h3, @opp_code]] = [sc.units_total, sc.surface_total] }
    end

    h3s = Cell.where(municipality_code: @mun_code).pluck(:h3)
    InfoCell.where(h3: h3s, opportunity_code: @opp_code).find_each do |ic|
      map[[ic.h3, @opp_code]] ||= [ic.units.to_i, ic.surface.to_d]
    end

    map
  end

  # Returns: {h3 => {"acc_walk_m2_habitacional" => 0.032, ...}}
  def load_accessibility_hash
    Accessibility
      .joins(:travel_mode)
      .where(scenario_id: @scenario.id)
      .pluck(
        "accessibilities.h3",
        "travel_modes.mode",
        "accessibilities.accessibility_type",
        "accessibilities.opportunity_code",
        "accessibilities.value"
      )
      .each_with_object(Hash.new { |h, k| h[k] = {} }) do |(h3, mode, acc_type, opp, value), hash|
        mode_prefix = mode == "car" ? "auto" : mode
        type_prefix = acc_type == "surface" ? "m2" : "n"
        hash[h3]["acc_#{mode_prefix}_#{type_prefix}_#{opp}"] = value.to_f
      end
  end

  # ── Montecarlo core ───────────────────────────────────────────────────────────

  def sample_cell(valid_h3s, rng)
    utilities = valid_h3s.map { |h3| [h3, compute_utility(h3)] }

    max_u     = utilities.map(&:last).max
    exp_utils = utilities.map { |h3, u| [h3, Math.exp(u - max_u)] }
    total     = exp_utils.sum(&:last)
    return valid_h3s.sample(random: rng) if total.zero?

    r   = rng.rand
    cum = 0.0
    exp_utils.each do |h3, e|
      cum += e / total
      return h3 if r <= cum
    end
    exp_utils.last[0]
  end

  def compute_utility(h3)
    cell = @cells_acc.fetch(h3, {}).dup
    cell["superficie_construida"] = @surface_per_unit
    cell["superficie_terreno"]    = @land_per_unit
    cell["ubicacion"]             = @cells_cap[h3][:location_type] == "urbano" ? 1.0 : 0.0

    @mnl_vars.sum do |var|
      beta = @mnl_coeffs[var].to_f
      val  = var == "const" ? 1.0 : cell.fetch(var, 0.0)
      beta * val
    end
  end

  def location_ok?(location_type)
    if HUELLA_OPP_CODES.include?(@opp_code)
      location_type == "rural"
    elsif SURFACE_OPP_CODES.include?(@opp_code)
      location_type == "urbano"
    else
      # Fallback: usar location_restriction del agent_type
      return true if @location_filter.blank? || @location_filter == "ambos"
      @location_filter == location_type
    end
  end

  # ── Persistence ───────────────────────────────────────────────────────────────

  def parse_json(value)
    return value unless value.is_a?(String)
    JSON.parse(value)
  end

  def write_placements!
    return if @placements.empty?

    upserts = @placements.map do |h3, delta|
      pre    = @pre_sim[h3]
      base_u = pre ? pre.units_total.to_i   - pre.units_delta.to_i   : @parent_base.fetch([h3, @opp_code], [0, 0])[0].to_i
      base_s = pre ? pre.surface_total.to_f - pre.surface_delta.to_f : @parent_base.fetch([h3, @opp_code], [0, 0])[1].to_f
      pre_du = pre&.units_delta.to_i
      pre_ds = pre&.surface_delta.to_f

      {
        scenario_id:      @scenario.id,
        h3:               h3,
        opportunity_code: @opp_code,
        units_delta:      pre_du + delta[:units],
        surface_delta:    pre_ds + delta[:surface],
        units_total:      base_u + pre_du + delta[:units],
        surface_total:    base_s + pre_ds + delta[:surface]
      }
    end

    ScenarioCell.upsert_all(upserts, unique_by: :idx_scenario_cells_unique)
  end
end
