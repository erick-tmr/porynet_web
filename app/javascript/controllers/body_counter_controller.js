import { Controller } from "@hotwired/stimulus"
import { bump, countOf, load, save, subscribe } from "lib/progress_store"

export default class extends Controller {
  static targets = ["have"]
  static values = {
    game: { type: String, default: "yellow" },
    dex: String,
    quota: { type: Number, default: 1 },
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

  add() {
    this.#commit(1)
  }

  remove() {
    this.#commit(-1)
  }

  stop(event) {
    event.stopPropagation()
  }

  #commit(delta) {
    const next = bump(this.state, this.gameValue, this.dexValue, delta, this.quotaValue)
    if (!save(next)) {
      this.element.classList.add("is-error")
      return
    }
    this.state = next
    this.element.classList.remove("is-error")
    this.#render()
  }

  #render() {
    const have = countOf(this.state, this.gameValue, this.dexValue)
    this.haveTargets.forEach((slot) => { slot.textContent = String(have) })
    this.element.classList.toggle("is-met", have >= this.quotaValue)
  }
}
