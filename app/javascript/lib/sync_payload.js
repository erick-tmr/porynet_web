export const KEYS_PER_BATCH = 64
export const SYNCED_EVENT = "porynet:synced"

function forGame(state, kind, game) {
  const games = state[kind] || {}
  return games[game] || {}
}

function markIds(state, game) {
  return Object.keys(forGame(state, "collected", game))
}

function bodyCounts(state, game) {
  return Object.fromEntries(
    Object.entries(forGame(state, "bodies", game)).filter(([ , count ]) => count > 0),
  )
}

function chunk(ids, size) {
  const out = []
  for (let at = 0; at < ids.length; at += size) out.push(ids.slice(at, at + size))
  return out
}

function ticked(ids) {
  return Object.fromEntries(ids.map((id) => [ id, true ]))
}

function held(counts, ids) {
  return Object.fromEntries(ids.map((id) => [ id, counts[id] ]))
}

export function tally(state, game) {
  const marks = markIds(state, game).length
  const counts = bodyCounts(state, game)
  const species = Object.keys(counts)
  return {
    marks,
    species: species.length,
    pokemon: species.reduce((sum, dex) => sum + counts[dex], 0),
    records: marks + species.length,
  }
}

export function batches(state, game, size = KEYS_PER_BATCH) {
  const counts = bodyCounts(state, game)
  return [
    ...chunk(markIds(state, game), size).map((ids) => (
      { collected: { [game]: ticked(ids) }, bodies: {}, records: ids.length }
    )),
    ...chunk(Object.keys(counts), size).map((ids) => (
      { collected: {}, bodies: { [game]: held(counts, ids) }, records: ids.length }
    )),
  ]
}
