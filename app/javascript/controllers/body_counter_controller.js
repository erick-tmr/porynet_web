import { Controller } from "@hotwired/stimulus"
import { bump, countOf, isSet, load, save, subscribe } from "lib/progress_store"

export default class extends Controller {
  static targets = ["have", "want"]
  static values = {
    game: { type: String, default: "yellow" },
    dex: String,
    covers: Array,
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

  #stages() {
    return this.coversValue.length ? this.coversValue : [ this.dexValue ]
  }

  #need() {
    const spare = this.#stages().filter(
      (dex) => dex !== this.dexValue && isSet(this.state, "caught", this.gameValue, dex),
    )
    return this.#stages().length - spare.length
  }

  #commit(delta) {
    const next = bump(this.state, this.gameValue, this.dexValue, delta, this.#need())
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
    const need = this.#need()
    this.haveTargets.forEach((slot) => { slot.textContent = String(have) })
    this.wantTargets.forEach((slot) => { slot.textContent = String(need) })
    this.element.classList.toggle("is-met", have >= need)
  }
}
