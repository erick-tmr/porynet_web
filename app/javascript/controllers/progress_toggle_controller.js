import { Controller } from "@hotwired/stimulus"
import { countSet, isSet, load, save, subscribe, toggle } from "lib/progress_store"

// Click-to-tick for everything outside the map overlay: the items and hidden items on a step,
// the come-back-later cards, and the Pokemon you can catch here. One instance covers a whole
// page; each tickable element names its own kind and id.
//
// Like the map controller this only moves classes and writes counts, so every string on the
// page stays server-rendered and translatable.
export default class extends Controller {
  static targets = ["item", "count"]
  static values = {
    game: { type: String, default: "yellow" },
    hint: { type: String, default: "" },
    hintMs: { type: Number, default: 2200 },
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
    clearTimeout(this.hintTimer)
    this.unsubscribe()
  }

  // Also bound to Enter and Space, since these tick targets are cards rather than real buttons.
  toggle(event) {
    event.preventDefault()
    const { kind, progressId } = event.currentTarget.dataset
    this.state = toggle(this.state, kind, this.gameValue, progressId)
    save(this.state)
    this.#render()
    this.hintValue = progressId
  }

  // The toast confirms what the click did, then gets out of the way.
  hintValueChanged() {
    clearTimeout(this.hintTimer)
    this.itemTargets.forEach((item) => {
      item.classList.toggle("is-hinting", item.dataset.progressId === this.hintValue)
    })
    if (this.hintValue) {
      this.hintTimer = setTimeout(() => { this.hintValue = "" }, this.hintMsValue)
    }
  }

  #render() {
    this.itemTargets.forEach((item) => {
      const ticked = isSet(this.state, item.dataset.kind, this.gameValue, item.dataset.progressId)
      item.classList.toggle("is-done", ticked)
      item.setAttribute("aria-pressed", String(ticked))
    })
    this.countTargets.forEach((slot) => {
      const ids = slot.dataset.progressIds.split(" ").filter(Boolean)
      slot.textContent = String(countSet(this.state, slot.dataset.kind, this.gameValue, ids))
    })
  }
}
