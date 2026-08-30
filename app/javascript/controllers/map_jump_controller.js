import { Controller } from "@hotwired/stimulus"

// The letter chips in the prose are handles onto the maps above them. A step says "take the ladder
// E13" and the reader has to find E13 for themselves, which on a five-floor cave means scrolling
// back up and reading five legends. Clicking the chip does it instead: the page moves to the map
// that draws that pin and the pin opens its own hint, so the letter answers itself.
//
// Which map, when several draw the same letter. A staircase and a hole wear one key at both ends
// because they are one thing seen twice, and either end answers the question, so the first one on
// the page wins: it is the one the reader is already nearest. Every other category numbers from
// one per map, so an H1 on three floors is three different hidden items that happen to share a
// letter, and only the map the chip itself came from is the right answer.
// Kept in sync with Walkthrough::LINKED_CATEGORIES.
const LINKED = new Set(["exit", "hole"])

// A leg page stacks several stops, each with its own maps and its own steps, so a chip belongs to
// the stop it sits in and the search never leaves that band. A single-stop page has no band, and
// falls back to the whole page.
const BAND = ".pn-wt-band-wrap"

// The jump lands rather than glides. A smooth `scrollIntoView` is inert wherever the browser has
// smooth scrolling off (headless Chrome, the system-test run, a reader who asked for less motion),
// which makes the chip look broken instead of merely unanimated; and a floor five maps down is a
// few thousand pixels away, which is a long ride to watch for something the reader asked to be
// taken to. `scroll-margin-top` on the block is what keeps it clear of the sticky bars.

export default class extends Controller {
  go(event) {
    const { markKey, markMap } = event.currentTarget.dataset
    const scope = event.currentTarget.closest(BAND) || this.element
    const blocks = [...scope.querySelectorAll("[data-map-markers-map-value]")]
      .filter((block) => this.#pin(block, markKey))
    if (blocks.length === 0) return

    const target = this.#target(blocks, markKey, markMap)
    target.scrollIntoView({ block: "start" })
    this.#raiseHint(scope, target, this.#pin(target, markKey))
  }

  #target(blocks, key, map) {
    if (LINKED.has(this.#pin(blocks[0], key).dataset.cat)) return blocks[0]

    return blocks.find((block) => block.dataset.mapMarkersMapValue === map) || blocks[0]
  }

  #pin(block, key) {
    return block.querySelector(`[data-role="marker"][data-marker-key="${key}"]`)
  }

  // Handing the selection to each map's own controller rather than setting classes here, so a pin
  // raised from the prose and one clicked on the map are the same state and dismiss the same way.
  //
  // Every other map on the page is cleared as well. A hint belongs to the block it is drawn in, so
  // a reader jumping from floor to floor would otherwise leave one open behind them on each, and
  // clicking the bare map only ever closes the one they are looking at.
  #raiseHint(scope, block, pin) {
    scope.querySelectorAll("[data-map-markers-map-value]").forEach((other) => {
      const map = this.application.getControllerForElementAndIdentifier(other, "map-markers")
      if (map) map.hintValue = other === block ? pin.dataset.markerId : ""
    })
  }
}
