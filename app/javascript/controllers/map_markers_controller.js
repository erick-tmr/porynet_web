import { Controller } from "@hotwired/stimulus"

// Positions hidden-item markers over an area map from their data-x / data-y
// percentages. Done in JS (element.style) rather than inline style attributes,
// which the site's Content-Security-Policy blocks.
export default class extends Controller {
  static targets = ["marker"]

  connect() {
    this.markerTargets.forEach((el) => {
      el.style.left = `${this.#pct(el.dataset.x)}%`
      el.style.top = `${this.#pct(el.dataset.y)}%`
    })
  }

  #pct(value) {
    return Math.max(0, Math.min(100, parseFloat(value) * 100))
  }
}
