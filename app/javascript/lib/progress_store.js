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

const KINDS = ["collected", "caught"]

function emptyState() {
  return { v: SCHEMA_VERSION, collected: {}, caught: {} }
}

function normalize(raw) {
  if (!raw || raw.v !== SCHEMA_VERSION) return emptyState()
  const state = emptyState()
  KINDS.forEach((kind) => {
    const games = raw[kind]
    if (games && typeof games === "object") state[kind] = { ...games }
  })
  return state
}

export function load() {
  try {
    return normalize(JSON.parse(localStorage.getItem(STORAGE_KEY)))
  } catch {
    return emptyState()
  }
}

export function save(state) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state))
    return true
  } catch {
    return false
  }
}

export function isSet(state, kind, game, id) {
  return Boolean(state[kind]?.[game]?.[id])
}

// Returns a new state; the caller decides whether to persist it.
export function toggle(state, kind, game, id) {
  const forGame = { ...(state[kind]?.[game] || {}) }
  if (forGame[id]) delete forGame[id]
  else forGame[id] = true
  return { ...state, [kind]: { ...state[kind], [game]: forGame } }
}

export function countSet(state, kind, game, ids) {
  return ids.filter((id) => isSet(state, kind, game, id)).length
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

// Fires when another tab writes the store, so two open walkthrough pages stay in step.
export function subscribe(onChange) {
  const listener = (event) => {
    if (event.key !== STORAGE_KEY) return
    onChange(load())
  }
  window.addEventListener("storage", listener)
  return () => window.removeEventListener("storage", listener)
}
