import { Controller } from "@hotwired/stimulus"

// Toggles the Oak Challenge between "Oak mode" (Pokédex registration) and
// "Living Dex" (each specimen). Flips an is-active class on the matching button
// and its stat sub-card; all styling lives in CSS.
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
