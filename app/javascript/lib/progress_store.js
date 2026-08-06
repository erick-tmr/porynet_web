// Guest progress: which map markers a visitor has ticked and which Pokemon they have caught.
//
// There is no account and no server state, so this lives in localStorage. It is deliberately a
// set of pure functions over a plain state object rather than a stateful singleton: every caller
// loads, derives, and saves, which keeps the store trivial to reason about and to test.
//
// Every read and write is wrapped, because localStorage throws rather than returns null when it
// is disabled, when Safari is in private mode, and when a quota is exceeded. A caller that
// cannot persist still gets a working page for the session.

export const STORAGE_KEY = "porynet.progress"
export const SCHEMA_VERSION = 1

const KINDS = ["collected", "caught", "bodies"]

function emptyState() {
  return { v: SCHEMA_VERSION, collected: {}, caught: {}, bodies: {} }
}

function backfill(state) {
  Object.entries(state.caught).forEach(([game, dexes]) => {
    const bodies = { ...(state.bodies[game] || {}) }
    Object.keys(dexes).forEach((dex) => { bodies[dex] ||= 1 })
    state.bodies[game] = bodies
  })
  return state
}

function normalize(raw) {
  if (!raw || raw.v !== SCHEMA_VERSION) return emptyState()
  const state = emptyState()
  KINDS.forEach((kind) => {
    const games = raw[kind]
    if (games && typeof games === "object") state[kind] = { ...games }
  })
  return backfill(state)
}

export function load() {
  try {
    return normalize(JSON.parse(localStorage.getItem(STORAGE_KEY)))
  } catch {
    return emptyState()
  }
}

export const CHANGE_EVENT = "porynet:progress"

export function save(state) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
    window.dispatchEvent(new CustomEvent(CHANGE_EVENT))
    return true
  } catch {
    return false
  }
}

export function isSet(state, kind, game, id) {
  return Boolean(state[kind]?.[game]?.[id])
}

function write(state, kind, game, id, value) {
  const forGame = { ...(state[kind]?.[game] || {}) }
  if (value) forGame[id] = value
  else delete forGame[id]
  return { ...state, [kind]: { ...state[kind], [game]: forGame } }
}

// Returns a new state; the caller decides whether to persist it.
export function toggle(state, kind, game, id) {
  const on = !isSet(state, kind, game, id)
  const next = write(state, kind, game, id, on)
  if (kind !== "caught") return next

  return write(next, "bodies", game, id, on ? Math.max(1, countOf(state, game, id)) : 0)
}

export function countSet(state, kind, game, ids) {
  return ids.filter((id) => isSet(state, kind, game, id)).length
}

export function countOf(state, game, dex) {
  return state.bodies?.[game]?.[dex] || 0
}

export function needFor(state, game, dex, covers) {
  const stages = covers.length ? covers : [ dex ]
  const spare = stages.filter((id) => id !== dex && isSet(state, "caught", game, id))
  return stages.length - spare.length
}

export function owedFor(state, game, dex, covers) {
  return Math.max(0, needFor(state, game, dex, covers) - countOf(state, game, dex))
}

export function bump(state, game, dex, delta, quota) {
  const count = Math.min(quota, Math.max(0, countOf(state, game, dex) + delta))
  return write(write(state, "bodies", game, dex, count), "caught", game, dex, count > 0)
}

export function exportJson(state) {
  return JSON.stringify(state)
}

// Returns null rather than throwing, so a bad paste is a rejected import and not a broken page.
export function importJson(raw) {
  try {
    const parsed = JSON.parse(raw)
    if (!parsed || parsed.v !== SCHEMA_VERSION) return null
    return normalize(parsed)
  } catch {
    return null
  }
}

export function subscribe(onChange) {
  const listener = (event) => {
    if (event.type === "storage" && event.key !== STORAGE_KEY) return
    onChange(load())
  }
  window.addEventListener("storage", listener)
  window.addEventListener(CHANGE_EVENT, listener)
  return () => {
    window.removeEventListener("storage", listener)
    window.removeEventListener(CHANGE_EVENT, listener)
  }
}
