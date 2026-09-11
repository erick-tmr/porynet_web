import { Controller } from "@hotwired/stimulus"
import { token } from "lib/csrf"
import { CHANGE_EVENT } from "lib/progress_store"
import { SYNCED_EVENT } from "lib/sync_payload"

function merge(into, change) {
  return { marks: { ...into.marks, ...change.marks },
    bodies: { ...into.bodies, ...change.bodies } }
}

export default class extends Controller {
  static values = {
    url: String,
    game: { type: String, default: "yellow" },
    ready: Boolean,
    retryMs: { type: Number, default: 4000 },
  }

  connect() {
    this.pending = []
    this.onChange = (event) => this.#collect(event.detail)
    this.onSynced = () => { this.readyValue = true }
    window.addEventListener(CHANGE_EVENT, this.onChange)
    window.addEventListener(SYNCED_EVENT, this.onSynced)
  }

  disconnect() {
    window.removeEventListener(CHANGE_EVENT, this.onChange)
    window.removeEventListener(SYNCED_EVENT, this.onSynced)
    clearTimeout(this.retry)
    this.aborter?.abort()
  }

  readyValueChanged() {
    if (this.pending) this.#flush()
  }

  #collect(detail) {
    const change = detail?.changed?.[this.gameValue]
    if (!this.urlValue || !change) return

    this.pending.push(change)
    this.#flush()
  }

  async #flush() {
    if (!this.readyValue || this.sending || this.pending.length === 0) return

    clearTimeout(this.retry)
    const change = this.pending.reduce(merge, { marks: {}, bodies: {} })
    this.pending = []
    this.sending = true
    const landed = await this.#push(change)
    this.sending = false
    if (this.aborter.signal.aborted) return
    if (landed) return this.#flush()

    this.pending.unshift(change)
    this.retry = setTimeout(() => this.#flush(), this.retryMsValue)
  }

  async #push(change) {
    const aborter = new AbortController()
    this.aborter = aborter
    try {
      const response = await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": token(),
        },
        body: JSON.stringify(change),
        signal: aborter.signal,
      })
      return response.ok
    } catch {
      return false
    }
  }
}
