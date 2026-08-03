import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button" ]

  toggle() {
    this.#setOpen(!this.element.classList.contains("is-open"))
  }

  close() {
    this.#setOpen(false)
  }

  #setOpen(open) {
    this.element.classList.toggle("is-open", open)
    this.buttonTarget.setAttribute("aria-expanded", String(open))
  }
}
