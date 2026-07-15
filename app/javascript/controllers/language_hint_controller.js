import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 1200 } }

  connect() {
    if (this.#reducedMotion()) return
    this.timeout = setTimeout(() => this.reveal(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  reveal() {
    this.element.addEventListener("animationend", () => this.hide(), { once: true })
    this.element.classList.add("is-shown")
  }

  hide() {
    this.element.classList.remove("is-shown")
  }

  #reducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }
}
