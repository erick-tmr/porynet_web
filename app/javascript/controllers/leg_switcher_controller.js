import { Controller } from "@hotwired/stimulus";

// Both sticky bars are measured into custom properties rather than hard-coded: the nav is
// taller on wide screens, taller again while the burger panel is open, and the switcher
// itself shrinks to a stepper on narrow ones.
const CLEARANCE = 8;
const SPY_LINE = 12;

export default class extends Controller {
  static targets = [
    "bar", "rail", "chip", "row", "band", "seg",
    "stopNo", "stopName", "position", "sheetToggle", "prevArrow", "nextArrow"
  ];

  connect() {
    this.nav = document.querySelector(".pn-nav");
    this.reposition = this.reposition.bind(this);
    this.closeOnOutside = this.closeOnOutside.bind(this);
    window.addEventListener("scroll", this.reposition, { passive: true });
    window.addEventListener("resize", this.reposition);
    document.addEventListener("pointerdown", this.closeOnOutside);
    this.observer = new ResizeObserver(this.reposition);
    this.observer.observe(this.nav);
    this.observer.observe(this.barTarget);
    this.reposition();
  }

  disconnect() {
    window.removeEventListener("scroll", this.reposition);
    window.removeEventListener("resize", this.reposition);
    document.removeEventListener("pointerdown", this.closeOnOutside);
    this.observer.disconnect();
  }

  jump(event) {
    this.#goTo(Number(event.currentTarget.dataset.stop));
  }

  goPrev() {
    this.#goTo(this.activeStop - 1);
  }

  goNext() {
    this.#goTo(this.activeStop + 1);
  }

  toggleSheet() {
    this.#setOpen(!this.barTarget.classList.contains("is-open"));
  }

  closeSheet() {
    this.#setOpen(false);
  }

  closeOnOutside(event) {
    if (!this.barTarget.contains(event.target)) this.#setOpen(false);
  }

  // A one-stop leg gets the same bar reduced to a plate: it still needs the offsets measured so
  // it parks under the nav, but there is nothing to spy on, step through or open.
  reposition() {
    this.#measure();
    if (this.hasChipTarget) this.#paint(this.#spy());
  }

  #measure() {
    this.navHeight = this.nav.getBoundingClientRect().height;
    this.barHeight = this.barTarget.getBoundingClientRect().height;
    this.element.style.setProperty("--pn-nav-h", `${Math.round(this.navHeight)}px`);
    this.element.style.setProperty("--pn-legsw-h", `${Math.round(this.barHeight)}px`);
  }

  #offset() {
    return this.navHeight + this.barHeight + CLEARANCE;
  }

  // The stop the reader is looking at is the last band whose head has passed under the bars.
  // A leg that ends back at its gym draws a second band for a stop it already listed, so the
  // band names its own stop rather than the switcher counting bands.
  #spy() {
    let stop = 0;
    for (const band of this.bandTargets) {
      if (band.getBoundingClientRect().top <= this.#offset() + SPY_LINE) {
        stop = Number(band.dataset.stop);
      }
    }
    return stop;
  }

  // Clamped to the stops, not to the bands: a leg that ends back at its gym draws one band more
  // than it has stops, so stepping past the last one would otherwise land on a stop with no chip.
  #goTo(stop) {
    const target = Math.min(Math.max(stop, 0), this.chipTargets.length - 1);
    const top = this.bandTargets[target].getBoundingClientRect().top + window.scrollY - this.#offset();
    window.scrollTo({ top: Math.max(0, top), behavior: "instant" });
    this.#setOpen(false);
    this.#paint(target);
  }

  #setOpen(open) {
    if (!this.hasSheetToggleTarget) return;

    this.barTarget.classList.toggle("is-open", open);
    this.sheetToggleTarget.setAttribute("aria-expanded", String(open));
  }

  // Painted straight onto the elements so the bar never lags a frame behind the scroll.
  #paint(stop) {
    this.activeStop = stop;
    this.chipTargets.forEach((chip, i) => chip.classList.toggle("is-active", i === stop));
    this.rowTargets.forEach((row, i) => row.classList.toggle("is-active", i === stop));
    this.segTargets.forEach((seg, i) => {
      seg.classList.toggle("is-done", i < stop);
      seg.classList.toggle("is-here", i === stop);
    });

    const chip = this.chipTargets[stop];
    this.stopNoTarget.textContent = chip.dataset.no;
    this.stopNameTarget.textContent = chip.dataset.name;
    this.positionTarget.textContent = `${stop + 1}/${this.chipTargets.length}`;
    this.prevArrowTarget.disabled = stop === 0;
    this.nextArrowTarget.disabled = stop === this.chipTargets.length - 1;
    this.#railFollow(chip);
  }

  // Keeps the active chip inside the wide rail without scrollIntoView dragging the page with it.
  #railFollow(chip) {
    const rail = this.railTarget;
    rail.scrollLeft = Math.max(0, chip.offsetLeft - rail.clientWidth / 2 + chip.offsetWidth / 2);
  }
}
