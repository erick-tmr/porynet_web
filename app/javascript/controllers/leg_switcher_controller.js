import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["chip", "band"];

  connect() {
    this.onScroll = this.onScroll.bind(this);
    window.addEventListener("scroll", this.onScroll, { passive: true });
    this.onScroll();
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll);
  }

  jump(event) {
    const band = this.bandTargets.find((el) => el.dataset.slug === event.currentTarget.dataset.slug);
    if (band) band.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  onScroll() {
    let active = this.bandTargets[0];
    for (const band of this.bandTargets) {
      if (band.getBoundingClientRect().top <= 175) active = band;
    }
    if (!active) return;

    for (const chip of this.chipTargets) {
      chip.classList.toggle("is-active", chip.dataset.slug === active.dataset.slug);
    }
  }
}
