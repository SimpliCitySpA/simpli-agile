export const PALETTES = {
  blue: {
    0: "#e5e7eb",
    1: "#dbeafe",
    2: "#93c5fd",
    3: "#3b82f6",
    4: "#1d4ed8",
    5: "#0b3aa4"
  },
  orange: {
    0: "#e5e7eb",
    1: "#ffedd5",
    2: "#fdba74",
    3: "#f97316",
    4: "#c2410c",
    5: "#7c2d12"
  }
}

export function fillColorExpr(palette) {
  const p = PALETTES[palette] || PALETTES.blue
  return [
    "match",
    ["get", "class"],
    1, p[1],
    2, p[2],
    3, p[3],
    4, p[4],
    5, p[5],
    "#f3f4f6"
  ]
}
