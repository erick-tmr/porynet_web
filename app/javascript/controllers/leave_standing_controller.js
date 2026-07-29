import { Controller } from "@hotwired/stimulus"
import { isSet, load, save, subscribe, toggle } from "lib/progress_store"

// The "leave these four standing" checklist under Nugget Bridge: four Trainers the Mew glitch
// needs left un-beaten. Each card is bound by data-progress-id to the very collected/marker key
// its pin on the annotated maps stores under, so beating one on its map flips its card here and
// beating it here flips the pin. This is the inverse of a chore: a defeated (ticked) card is the
// bad state, and the header counts the ones still standing. Like the map controller, this only
// moves classes and a count; every string on the page is server-rendered in both locales.
export default class extends Controller {
  static targets = ["card", "standing"]
  static values = { game: { type: String, default: "yellow" } }

  connect() {
    this.state = load()
    this.unsubscribe = subscribe((state) => {
      this.state = state
      this.#render()
    })
    this.#render()
  }

  disconnect() {
    this.unsubscribe()
  }

  // The dedicated "I BEAT THEM / UNDO" button toggles the shared key. We only adopt the change
  // once the write lands, so a blocked localStorage leaves the card untouched and flags itself.
  toggle(event) {
    const card = event.currentTarget.closest("[data-progress-id]")
    const next = toggle(this.state, "collected", this.gameValue, card.dataset.progressId)
    if (save(next)) {
      this.state = next
      card.classList.remove("is-error")
      this.#render()
    } else {
      card.classList.add("is-error")
    }
  }

  #render() {
    let standing = 0
    this.cardTargets.forEach((card) => {
      const defeated = isSet(this.state, "collected", this.gameValue, card.dataset.progressId)
      card.classList.toggle("is-defeated", defeated)
      card.querySelector(".pn-ls-card__btn").setAttribute("aria-pressed", String(defeated))
      if (!defeated) standing += 1
    })
    this.standingTargets.forEach((slot) => { slot.textContent = String(standing) })
  }
}
