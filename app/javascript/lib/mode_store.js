export const STORAGE_KEY = "porynet.modes"
export const CHANGE_EVENT = "porynet:modes"
export const SCHEMA_VERSION = 1

export const MODES = [ "living", "oak" ]

function emptyState() {
  return { v: SCHEMA_VERSION, living: {}, oak: {} }
}

function normalize(raw) {
  if (!raw || raw.v !== SCHEMA_VERSION) return emptyState()
  const state = emptyState()
  MODES.forEach((mode) => {
    const games = raw[mode]
    if (games && typeof games === "object") state[mode] = { ...games }
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
    window.dispatchEvent(new CustomEvent(CHANGE_EVENT))
    return true
  } catch {
    return false
  }
}

export function isOn(state, mode, game) {
  return state[mode]?.[game] === true
}

export function setMode(state, mode, game, on) {
  return { ...state, [mode]: { ...state[mode], [game]: on } }
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
