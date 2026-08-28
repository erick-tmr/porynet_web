import { Controller } from "@hotwired/stimulus"
import { isSet, load, save, subscribe, toggle } from "lib/progress_store"

// The two Poké Balls at the back of the Fighting Dojo. The game lets you open exactly one, so
// these are a radio rather than a pair of checkboxes: picking the second card puts the first back
// and greys the loser out the way the ball you walked past stays shut for the rest of the save.
//
// Opening a ball is a catch, so a pick ticks the species itself in the guest progress store: the
// same tick the catch card below carries and the one the living dex counts, which is why the two
// move together. Like every other tick on the page this only moves classes and fills one
// server-rendered slot; no user-visible string lives here.
export default class extends Controller {
  static targets = ["item", "state", "name"]
  static values = { game: { type: String, default: "yellow" } }

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

  // Bound to Enter and Space too, since a pick is a card rather than a real button.
  toggle(event) {
    event.preventDefault()
    const card = event.currentTarget
    this.#commit(this.#on(this.state, card) ? null : card)
  }

  clear(event) {
    event.preventDefault()
    this.#commit(null)
  }

  // localStorage throws when it is disabled, full, or in private mode, so the card only moves once
  // the write lands; a refused write leaves the room as it was and says so under the cards.
  #commit(card) {
    const next = this.itemTargets.reduce((state, item) => this.#write(state, item, item === card), this.state)
    if (save(next)) {
      this.state = next
      this.element.classList.remove("is-error")
      this.#render()
    } else {
      this.element.classList.add("is-error")
      this.stateTarget.hidden = false
    }
  }

  #write(state, item, on) {
    return this.#on(state, item) === on ? state : toggle(state, item.dataset.kind, this.gameValue, item.dataset.progressId)
  }

  #on(state, item) {
    return isSet(state, item.dataset.kind, this.gameValue, item.dataset.progressId)
  }

  // Holding both is only possible by trading for the other half, and then neither ball is the one
  // you walked past, so a save with both ticked greys nothing out and claims no pick.
  #render() {
    const held = this.itemTargets.filter((item) => this.#on(this.state, item))
    const picked = held.length === 1 ? held[0] : null
    this.itemTargets.forEach((item) => {
      item.classList.toggle("is-done", held.includes(item))
      item.classList.toggle("is-gone", picked !== null && item !== picked)
      item.setAttribute("aria-pressed", String(held.includes(item)))
    })
    this.stateTarget.hidden = picked === null
    if (picked) this.nameTarget.textContent = picked.dataset.pickName
  }
}
