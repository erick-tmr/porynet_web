import { Controller } from "@hotwired/stimulus"
import { MODES, isOn, load, save, setMode, subscribe } from "lib/mode_store"

// The LIVING DEX and OAK CHALLENGE switches. One instance sits on the page root and covers every
// switch on it: the pair in the nav, which rides along on every walkthrough page, and the chips in
// the index hero.
//
// All it does is put a class on the root and set aria-pressed. What that class hides or recolours
// is a CSS rule, so every string on the page stays server-rendered and translatable.
//
// The class marks a mode *off*, never on: both modes default to on, so the server renders no class
// at all and the common case paints right the first time.
export default class extends Controller {
  static targets = [ "switch" ]
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

  // A failed write still flips the page. Unlike a ticked-off item there is nothing to lose here,
  // so a visitor whose localStorage is blocked gets working switches for the session.
  toggle(event) {
    const { mode } = event.currentTarget.dataset
    this.state = setMode(this.state, mode, this.gameValue, !isOn(this.state, mode, this.gameValue))
    save(this.state)
    this.#render()
  }

  #render() {
    MODES.forEach((mode) => {
      this.element.classList.toggle(`pn-mode-${mode}-off`, !isOn(this.state, mode, this.gameValue))
    })
    this.switchTargets.forEach((el) => {
      el.setAttribute("aria-pressed", String(isOn(this.state, el.dataset.mode, this.gameValue)))
    })
  }
}
