import { Controller } from "@hotwired/stimulus"

// One-time onboarding nudge: after a short delay the Porygon bubble peeks in and
// points at the language toggle, then removes itself when its CSS animation ends.
// Skipped for visitors who prefer reduced motion. All motion lives in CSS — the
// controller only toggles the `is-shown` class on its own element.
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
