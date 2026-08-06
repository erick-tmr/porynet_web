import { Controller } from "@hotwired/stimulus"
import { load, owedFor, subscribe } from "lib/progress_store"

export default class extends Controller {
  static targets = ["bodies"]
  static values = {
    game: { type: String, default: "yellow" },
    entries: Array,
  }

  connect() {
    this.state = load()
    this.unsubscribe = subscribe((state) => {
      this.state = state
      this.#render()
    })
    this.#render()
  }

  disconnect() {
    this.unsubscribe()
  }

  #render() {
    const bodies = this.entriesValue.reduce(
      (total, entry) => total + owedFor(this.state, this.gameValue, entry.dex, entry.covers), 0,
    )
    this.bodiesTargets.forEach((slot) => { slot.textContent = String(bodies) })
    this.element.classList.toggle("is-clear", bodies === 0)
  }
}
