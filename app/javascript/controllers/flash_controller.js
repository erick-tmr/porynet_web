import { Controller } from "@hotwired/stimulus"

// A flash clears itself so it does not sit on the next page the trainer opens. Clicking it
// closes it sooner. The fade is CSS; the timer only decides when, then takes the row out of
// the layout so nothing below it stays pushed down.
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 6000 },
    fade: { type: Number, default: 240 }
  }

  connect() {
    this.timer = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timer)
    clearTimeout(this.remover)
  }

  dismiss() {
    clearTimeout(this.timer)
    if (this.element.classList.contains("is-gone")) return

    this.element.classList.add("is-gone")
    this.remover = setTimeout(() => { this.element.hidden = true }, this.fadeValue)
  }
}
