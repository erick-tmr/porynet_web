import { Controller } from "@hotwired/stimulus"

// A show/hide disclosure: the toggle button reveals or collapses the body. Hidden by default, so
// a heavy explainer stays out of the way until asked for. The SHOW/HIDE wording and chevron are
// swapped in CSS off the is-open class, so no user-facing string lives here.
export default class extends Controller {
  static targets = ["body", "toggle"]
  static values = { open: { type: Boolean, default: false } }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.element.classList.toggle("is-open", this.openValue)
    this.bodyTargets.forEach((body) => {
      body.hidden = !this.openValue
    })
    this.toggleTargets.forEach((button) => {
      button.setAttribute("aria-expanded", String(this.openValue))
    })
  }
}
