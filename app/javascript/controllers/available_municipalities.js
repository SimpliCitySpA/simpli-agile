// Singleton that fetches municipalities/regions with a base scenario once and caches the result.
// The fetch starts immediately on module import so it resolves as early as possible.
let _data = { municipalityCodes: [], regionCodes: [] }

const _promise = fetch('/municipalities/available')
  .then(r => r.json())
  .then(data => {
    _data = {
      municipalityCodes: (data.municipality_codes || []).map(String),
      regionCodes: (data.region_codes || []).map(String)
    }
    return _data
  })
  .catch(err => {
    console.error("Error cargando municipios disponibles:", err)
    return _data
  })

export function fetchAvailable() { return _promise }
export function getAvailable() { return _data }
