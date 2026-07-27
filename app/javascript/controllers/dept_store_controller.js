import { Controller } from "@hotwired/stimulus";

// The Celadon Dept. Store elevator: every floor panel is in the DOM; this shows one at a time
// and lights up its directory entry, so a reader rides between floors without a page load.
export default class extends Controller {
  static targets = ["floor", "entry"];
  static values = { start: String };

  connect() {
    this.show(this.startValue || this.firstFloor());
  }

  select(event) {
    this.show(event.currentTarget.dataset.floor);
  }

  firstFloor() {
    const first = this.floorTargets[0];
    return first ? first.dataset.floor : "";
  }

  show(id) {
    for (const floor of this.floorTargets) {
      floor.hidden = floor.dataset.floor !== id;
    }
    for (const entry of this.entryTargets) {
      entry.classList.toggle("is-active", entry.dataset.floor === id);
    }
  }
}
