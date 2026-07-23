import { Controller } from "@hotwired/stimulus"
import { isSet, load, save, subscribe, toggle } from "lib/progress_store"

// The clickable marker layer over an area map: trainers, important NPCs, item balls, hidden
// items and exits.
//
// Two rules shape this controller. Positions arrive as data attributes and are written through
// the CSSOM, because the page forbids inline styles and a percentage per marker cannot be a
// static class. And no user-visible string lives here: every label, status and toggle caption is
// rendered server-side in both locales, and this only ever moves classes around.

// Signposts, not chores: NPCs and exits raise a hint but never tick off, so they are skipped
// wherever progress is counted or stored. Kept in sync with Walkthrough::NON_TICKABLE.
const NON_TICKABLE = new Set(["exit", "npc"])

export default class extends Controller {
  static targets = ["layer", "canvas", "marker", "legendRow", "filter", "labelToggle", "counterDone"]
  static values = {
    game: { type: String, default: "yellow" },
    map: String,
    nativeW: Number,
    filter: { type: String, default: "all" },
    labels: { type: Boolean, default: true },
    hint: { type: String, default: "" },
  }

  connect() {
    this.markerTargets.forEach((marker) => {
      marker.style.setProperty("--mx", `${marker.dataset.x}%`)
      marker.style.setProperty("--my", `${marker.dataset.y}%`)
      marker.style.setProperty("--lane", marker.dataset.lane)
    })
    // A landscape map holds its own native pixel width so its CSS never scales the pixel art
    // below 1x; the frame scrolls instead. Portrait maps ignore the property.
    if (this.hasCanvasTarget) {
      this.canvasTarget.style.setProperty("--mm-native-w", `${this.nativeWValue}px`)
    }
    this.state = load()
    this.unsubscribe = subscribe((state) => {
      this.state = state
      this.#renderProgress()
    })
    this.#renderProgress()
    if (this.hasLayerTarget) this.layerTarget.classList.add("is-ready")
  }

  disconnect() {
    this.unsubscribe()
  }

  // Every pin and every legend row lands here. NPCs and exits are signposts rather than chores,
  // so they raise their hint without ticking anything.
  hit(event) {
    const { markerId, cat } = event.currentTarget.closest("[data-marker-id]").dataset
    if (!NON_TICKABLE.has(cat)) {
      this.state = toggle(this.state, "collected", this.gameValue, this.#key(markerId))
      save(this.state)
      this.#renderProgress()
    }
    this.hintValue = markerId
  }

  // A hint stays up until it is dismissed: clicking another marker moves it there (through #hit),
  // and clicking the bare map anywhere off a pin clears it. A click that lands on a marker or its
  // own hint is left to #hit, so this only ever fires for the empty map behind the pins.
  dismiss(event) {
    if (event.target.closest("[data-role='marker']")) return
    this.hintValue = ""
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
    this.#eachAnchored((element, id) => element.classList.toggle("is-selected", id === this.hintValue))
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
      if (NON_TICKABLE.has(cat)) return
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
