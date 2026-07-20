import { Controller } from "@hotwired/stimulus"
import { isSet, load, save, subscribe, toggle } from "lib/progress_store"

// The clickable marker layer over an area map: trainers, item balls, hidden items and exits.
//
// Two rules shape this controller. Positions arrive as data attributes and are written through
// the CSSOM, because the page forbids inline styles and a percentage per marker cannot be a
// static class. And no user-visible string lives here: every label, status and toggle caption is
// rendered server-side in both locales, and this only ever moves classes around.
export default class extends Controller {
  static targets = ["layer", "marker", "legendRow", "filter", "labelToggle", "counterDone"]
  static values = {
    game: { type: String, default: "yellow" },
    map: String,
    filter: { type: String, default: "all" },
    labels: { type: Boolean, default: true },
    hint: { type: String, default: "" },
    hintMs: { type: Number, default: 2200 },
  }

  connect() {
    this.markerTargets.forEach((marker) => {
      marker.style.setProperty("--mx", `${marker.dataset.x}%`)
      marker.style.setProperty("--my", `${marker.dataset.y}%`)
      marker.style.setProperty("--lane", marker.dataset.lane)
    })
    this.state = load()
    this.unsubscribe = subscribe((state) => {
      this.state = state
      this.#renderProgress()
    })
    this.#renderProgress()
    if (this.hasLayerTarget) this.layerTarget.classList.add("is-ready")
  }

  disconnect() {
    clearTimeout(this.hintTimer)
    this.unsubscribe()
  }

  // Every pin and every legend row lands here. Exits are signposts rather than chores, so they
  // raise their hint without ticking anything.
  hit(event) {
    const { markerId, cat } = event.currentTarget.closest("[data-marker-id]").dataset
    if (cat !== "exit") {
      this.state = toggle(this.state, "collected", this.gameValue, this.#key(markerId))
      save(this.state)
      this.#renderProgress()
    }
    this.hintValue = markerId
  }

  filter(event) {
    this.filterValue = event.currentTarget.dataset.cat
  }

  toggleLabels() {
    this.labelsValue = !this.labelsValue
  }

  filterValueChanged() {
    this.markerTargets.forEach((marker) => {
      marker.classList.toggle("is-filtered", !this.#matchesFilter(marker.dataset.cat))
    })
    this.filterTargets.forEach((pill) => {
      pill.classList.toggle("is-active", pill.dataset.cat === this.filterValue)
      pill.setAttribute("aria-pressed", String(pill.dataset.cat === this.filterValue))
    })
  }

  labelsValueChanged() {
    this.element.classList.toggle("is-labelled", this.labelsValue)
    this.labelToggleTargets.forEach((button) => {
      button.classList.toggle("is-on", this.labelsValue)
      button.setAttribute("aria-pressed", String(this.labelsValue))
    })
  }

  hintValueChanged() {
    clearTimeout(this.hintTimer)
    this.#eachAnchored((element, id) => element.classList.toggle("is-selected", id === this.hintValue))
    if (this.hintValue) {
      this.hintTimer = setTimeout(() => { this.hintValue = "" }, this.hintMsValue)
    }
  }

  #matchesFilter(cat) {
    return this.filterValue === "all" || this.filterValue === cat
  }

  // Marker ids are unique within a map, not across the game, so the store namespaces them.
  #key(markerId) {
    return `${this.mapValue}/${markerId}`
  }

  #renderProgress() {
    let done = 0
    this.#eachAnchored((element, id, cat) => {
      if (cat === "exit") return
      const ticked = isSet(this.state, "collected", this.gameValue, this.#key(id))
      element.classList.toggle("is-done", ticked)
      const button = element.querySelector("[aria-pressed]")
      if (button) button.setAttribute("aria-pressed", String(ticked))
      if (ticked && element.dataset.role === "marker") done += 1
    })
    this.counterDoneTargets.forEach((slot) => { slot.textContent = String(done) })
  }

  #eachAnchored(fn) {
    ;[...this.markerTargets, ...this.legendRowTargets].forEach((element) => {
      fn(element, element.dataset.markerId, element.dataset.cat)
    })
  }
}
