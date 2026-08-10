export const STORAGE_KEY = "porynet.sections"
export const CHANGE_EVENT = "porynet:sections"
export const SCHEMA_VERSION = 1

function emptyState() {
  return { v: SCHEMA_VERSION, folds: {} }
}

function normalize(raw) {
  if (!raw || raw.v !== SCHEMA_VERSION) return emptyState()
  const state = emptyState()
  if (raw.folds && typeof raw.folds === "object") state.folds = { ...raw.folds }
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

export function isOpen(state, game, id) {
  return state.folds[game]?.[id] !== false
}

export function setOpen(state, game, id, open) {
  const forGame = { ...state.folds[game] }
  if (open) delete forGame[id]
  else forGame[id] = false
  return { ...state, folds: { ...state.folds, [game]: forGame } }
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
