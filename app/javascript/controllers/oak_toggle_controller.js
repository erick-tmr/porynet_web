import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "statCard"]
  static values = { mode: { type: String, default: "oak" } }

  select(event) {
    this.modeValue = event.currentTarget.dataset.oakMode
  }

  modeValueChanged() {
    this.buttonTargets.forEach((btn) => {
      btn.classList.toggle("is-active", btn.dataset.oakMode === this.modeValue)
    })
    this.statCardTargets.forEach((card) => {
      card.classList.toggle("is-active", card.dataset.oakMode === this.modeValue)
    })
  }
}
