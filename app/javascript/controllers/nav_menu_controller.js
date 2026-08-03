import { Controller } from "@hotwired/stimulus"

// The narrow-screen nav: below the point where the bar stops fitting, the links, the crumb and
// the mode switches collapse behind a burger and reopen as a stacked panel.
//
// Which of the two the reader gets is a media query, not a decision made here. All this does is
// open and close, so the same markup serves both widths and nothing has to be re-rendered.
export default class extends Controller {
  static targets = [ "button" ]

  toggle() {
    this.#open(!this.element.classList.contains("is-open"))
  }

  close() {
    this.#open(false)
  }

  #open(open) {
    this.element.classList.toggle("is-open", open)
    this.buttonTarget.setAttribute("aria-expanded", String(open))
  }
}
