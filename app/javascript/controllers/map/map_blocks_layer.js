import { fillColorExpr } from "controllers/map/palettes"

export class MapBlocksLayer {
  constructor(controller) {
    this.c = controller
  }

  setVisible = (visible, map = this.c.map) => {
    if (!map) return
    const visibility = visible ? "visible" : "none"
    ;["blocks-fill", "blocks-outline", "blocks-hover"].forEach(id => {
      if (map.getLayer(id)) map.setLayoutProperty(id, "visibility", visibility)
    })
  }

  ensure = (map = this.c.map) => {
    if (!map) return

    if (!map.getSource("blocks")) {
      map.addSource("blocks", {
        type: "geojson",
        data: { type: "FeatureCollection", features: [] },
        promoteId: "block_id"
      })
    }

    if (!map.getLayer("blocks-fill")) {
      map.addLayer({
        id: "blocks-fill",
        type: "fill",
        source: "blocks",
        paint: {
          "fill-color": fillColorExpr(this.c._palette || "blue"),
          "fill-opacity": [
            "case",
            ["==", ["get", "class"], 0],
            0,
            0.75
          ]
        }
      })
    }

    if (!map.getLayer("blocks-outline")) {
      map.addLayer({
        id: "blocks-outline",
        type: "line",
        source: "blocks",
        paint: {
          "line-color": "rgba(17,24,39,0.15)",
          "line-width": 0.8
        }
      })
    }

    if (!map.getLayer("blocks-hover")) {
      map.addLayer({
        id: "blocks-hover",
        type: "fill",
        source: "blocks",
        paint: {
          "fill-color": "#111827",
          "fill-opacity": [
            "case",
            ["boolean", ["feature-state", "hover"], false],
            0.15,
            0
          ]
        }
      })
    }

    this.c.hover?.bindBlocksHoverTooltip?.()
  }

  applyPalette = (palette) => {
    const expr = fillColorExpr(palette)
    if (this.c.map?.getLayer("blocks-fill")) {
      this.c.map.setPaintProperty("blocks-fill", "fill-color", expr)
    }
  }
}
