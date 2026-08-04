import { Controller } from "@hotwired/stimulus"
import { bump, countOf, load, save, subscribe } from "lib/progress_store"

// The Living Dex stepper: how many bodies of one species you are holding, against the quota the
// page worked out. Only the number is written from here; every word around it is server-rendered
// and translated, and the quota-met wording is a sibling element CSS swaps in.
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

  // Same contract as the tick controller: the change is only adopted once localStorage accepts it,
  // so a browser that refuses to persist shows no phantom progress.
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
