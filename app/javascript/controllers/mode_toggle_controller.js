import { Controller } from "@hotwired/stimulus"
import { MODES, isOn, load, save, setMode, subscribe } from "lib/mode_store"

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
