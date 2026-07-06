class BlocksController < ApplicationController
  before_action :verify_data_request!

  def thematic
    mun_code = params.require(:municipality_code).to_i
    opp_code = params.require(:opportunity_code).to_s
    metric   = params.require(:metric).to_s

    unless %w[surface units].include?(metric)
      return render json: { error: "metric debe ser 'surface' o 'units'" }, status: :unprocessable_entity
    end

    info_col = metric == "surface" ? "surface" : "units"

    visual_mode = VisualMode.find_by!(
      municipality_code: mun_code,
      opportunity_code: opp_code,
      mode_code: metric,
      is_block: true
    )

    edges = [
      visual_mode.bin&.bin_0,
      visual_mode.bin&.bin_1,
      visual_mode.bin&.bin_2,
      visual_mode.bin&.bin_3,
      visual_mode.bin&.bin_4,
      visual_mode.bin&.bin_5
    ].compact.map(&:to_f)

    edges = [0, 0, 0, 0, 0, 0] if edges.length < 2

    conn = ActiveRecord::Base.connection.raw_connection

    rows_result = conn.exec_params(<<~SQL, [mun_code, opp_code])
      SELECT b.block_id, b.show_id, ST_AsGeoJSON(b.geometry) AS geom_json,
             COALESCE(ib.#{info_col}, 0) AS value
      FROM blocks b
      LEFT JOIN info_blocks ib
        ON ib.block_id = b.block_id
       AND ib.opportunity_code = $2
      WHERE b.municipality_code = $1
    SQL

    breaks = edges.dup
    actual_max = rows_result.map { |r| r["value"].to_f }.max || 0
    breaks[-1] = actual_max if actual_max > breaks.last

    features = rows_result.map do |r|
      v     = r["value"].to_f
      klass = v <= 0 ? 0 : bin_class(v, breaks)

      {
        type: "Feature",
        geometry: JSON.parse(r["geom_json"]),
        properties: {
          block_id: r["block_id"].to_i,
          show_id: r["show_id"]&.to_i,
          value: v,
          class: klass,
          municipality_code: mun_code,
          opportunity_code: opp_code,
          metric: metric
        }
      }
    end

    render json: { type: "FeatureCollection", features: features, breaks: breaks }
  end

  def accessibility
    mun_code = params.require(:municipality_code).to_i
    mode     = params.require(:mode).to_s
    opp_code = params.require(:opportunity_code).to_s
    acc_type = params[:accessibility_type].presence || "surface"

    unless %w[walk car].include?(mode)
      return render json: { error: "mode debe ser 'walk' o 'car'" }, status: :unprocessable_entity
    end

    unless %w[surface units].include?(acc_type)
      return render json: { error: "accessibility_type debe ser 'surface' o 'units'" }, status: :unprocessable_entity
    end

    mode_code = "acc_#{mode}"
    visual_mode = VisualMode.find_by!(
      municipality_code: mun_code,
      opportunity_code: opp_code,
      mode_code: mode_code,
      is_block: true
    )

    edges = [
      visual_mode.bin&.bin_0,
      visual_mode.bin&.bin_1,
      visual_mode.bin&.bin_2,
      visual_mode.bin&.bin_3,
      visual_mode.bin&.bin_4,
      visual_mode.bin&.bin_5
    ].compact.map(&:to_f)

    edges = [0, 0, 0, 0, 0, 0] if edges.length < 2

    conn = ActiveRecord::Base.connection.raw_connection

    rows_result = conn.exec_params(<<~SQL, [mun_code, mode, opp_code, acc_type])
      SELECT b.block_id, b.show_id, ST_AsGeoJSON(b.geometry) AS geom_json,
             COALESCE(ba.value, 0) AS value
      FROM blocks b
      LEFT JOIN block_accessibilities ba
        ON ba.block_id = b.block_id
       AND ba.travel_mode = $2
       AND ba.opportunity_code = $3
       AND ba.accessibility_type = $4
      WHERE b.municipality_code = $1
    SQL

    breaks = edges

    features = rows_result.map do |r|
      v     = r["value"].to_f
      klass = bin_class(v, breaks)

      {
        type: "Feature",
        geometry: JSON.parse(r["geom_json"]),
        properties: {
          block_id: r["block_id"].to_i,
          show_id: r["show_id"]&.to_i,
          value: v,
          class: klass,
          municipality_code: mun_code,
          mode: mode,
          opportunity_code: opp_code,
          accessibility_type: acc_type
        }
      }
    end

    render json: { type: "FeatureCollection", features: features, breaks: breaks }
  end

  def attractivity
    mun_code = params.require(:municipality_code).to_i
    mode     = params.require(:mode).to_s
    opp_code = params.require(:opportunity_code).to_s

    unless %w[walk car].include?(mode)
      return render json: { error: "mode debe ser 'walk' o 'car'" }, status: :unprocessable_entity
    end

    opp_acc_type = Opportunity.find_by(opportunity_code: opp_code)&.category == "POI" ? "units" : "surface"

    fetch_acc = ->(opp, acc_type) {
      BlockAccessibility
        .where(travel_mode: mode, opportunity_code: opp, accessibility_type: acc_type)
        .joins(:block)
        .where(blocks: { municipality_code: mun_code })
        .pluck(:block_id, :value)
        .to_h
    }

    opp_h = fetch_acc.(opp_code, opp_acc_type)
    hc_h  = fetch_acc.("HC", "units")
    hd_h  = fetch_acc.("HD", "units")
    p_h   = fetch_acc.("P",  "units")

    attractivity_val = ->(block_id) {
      denom = hc_h[block_id].to_f + hd_h[block_id].to_f + p_h[block_id].to_f
      return 0.0 if denom <= 0
      opp_h[block_id].to_f / denom
    }

    external_breaks = params[:breaks]&.split(",")&.map(&:to_f)

    conn = ActiveRecord::Base.connection.raw_connection
    rows_result = conn.exec_params(<<~SQL, [mun_code])
      SELECT block_id, show_id, ST_AsGeoJSON(geometry) AS geom_json
      FROM blocks
      WHERE municipality_code = $1
    SQL

    block_ids = rows_result.map { |r| r["block_id"].to_i }

    breaks = if external_breaks&.length == 6
      external_breaks
    else
      all_vals    = block_ids.map { |id| attractivity_val.(id) }
      nonzero     = all_vals.select { |v| v > 0 }
      nonzero.length >= 5 ? jenks_breaks(nonzero, 5) : [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    end

    features = rows_result.map do |r|
      block_id = r["block_id"].to_i
      v        = attractivity_val.(block_id)
      klass    = bin_class(v, breaks)

      {
        type: "Feature",
        geometry: JSON.parse(r["geom_json"]),
        properties: {
          block_id: block_id,
          show_id: r["show_id"]&.to_i,
          value: v.round(6),
          class: klass,
          municipality_code: mun_code,
          mode: mode,
          opportunity_code: opp_code
        }
      }
    end

    render json: { type: "FeatureCollection", features: features, breaks: breaks }
  end

  private

  def bin_class(value, edges)
    return 1 if edges.blank? || edges.length < 2
    v = value.to_f
    return 1 if v <= 0

    n = edges.length - 1
    (1..n).each do |k|
      return k if v <= edges[k]
    end
    n
  end

  def jenks_breaks(data, k)
    data = data.compact.map(&:to_f).sort
    n = data.length
    k = [[k, 1].max, n].min

    mat1 = Array.new(n + 1) { Array.new(k + 1, 0) }
    mat2 = Array.new(n + 1) { Array.new(k + 1, 0.0) }

    (1..k).each do |j|
      mat1[0][j] = 1
      mat2[0][j] = 0.0
      (1..n).each { |i| mat2[i][j] = Float::INFINITY }
    end

    v = 0.0

    (1..n).each do |l|
      s1 = s2 = w = 0.0
      (1..l).each do |m|
        i3 = l - m + 1
        val = data[i3 - 1]
        s2 += val * val
        s1 += val
        w += 1
        v = s2 - (s1 * s1) / w
        i4 = i3 - 1
        next if i4 < 0

        (2..k).each do |j|
          if mat2[l][j] >= (v + mat2[i4][j - 1])
            mat1[l][j] = i3
            mat2[l][j] = v + mat2[i4][j - 1]
          end
        end
      end
      mat1[l][1] = 1
      mat2[l][1] = v
    end

    breaks = Array.new(k + 1, 0.0)
    breaks[k] = data[-1]
    count = k
    idx = n

    while count > 1
      id = mat1[idx][count] - 1
      breaks[count - 1] = data[id]
      idx = mat1[idx][count] - 1
      count -= 1
    end

    breaks[0] = data[0]
    breaks
  end
end
