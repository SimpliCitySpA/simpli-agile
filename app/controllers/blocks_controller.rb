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
end
