import { Controller } from "@hotwired/stimulus"

// The Champion's three rosters. Which one Blue brings was decided by the first two rival battles,
// so all three are server-rendered and this shows the one the reader picks. The throne itself is a
// progress tick, so a tab click must not reach the card underneath it.
export default class extends Controller {
  static targets = ["tab", "panel"]

  pick(event) {
    event.preventDefault()
    event.stopPropagation()
    this.show(event.currentTarget.dataset.team)
  }

  show(key) {
    for (const tab of this.tabTargets) {
      const active = tab.dataset.team === key
      tab.classList.toggle("is-active", active)
      tab.setAttribute("aria-pressed", String(active))
    }
    for (const panel of this.panelTargets) {
      panel.hidden = panel.dataset.team !== key
    }
  }
}
