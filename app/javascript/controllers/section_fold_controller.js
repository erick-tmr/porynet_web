import { Controller } from "@hotwired/stimulus"
import { isOpen, load, save, setOpen, subscribe } from "lib/section_store"

// One catchable box: the header folds its grid away, and the choice sticks per game and stop. A
// failed write still folds, because a full or disabled localStorage should not keep the box open.
export default class extends Controller {
  static targets = [ "body", "toggle" ]
  static values = { game: { type: String, default: "yellow" }, id: String }

  connect() {
    this.state = load()
    this.unsubscribe = subscribe((state) => {
      this.state = state
      this.#render()
    })
    this.#render()
    this.element.classList.add("is-ready")
  }

  disconnect() {
    this.unsubscribe()
  }

  toggle() {
    this.state = setOpen(this.state, this.gameValue, this.idValue, !this.#open())
    save(this.state)
    this.#render()
  }

  #open() {
    return isOpen(this.state, this.gameValue, this.idValue)
  }

  #render() {
    const open = this.#open()
    this.element.classList.toggle("is-open", open)
    this.bodyTargets.forEach((body) => {
      body.hidden = !open
    })
    this.toggleTargets.forEach((button) => {
      button.setAttribute("aria-expanded", String(open))
    })
  }
}
