import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import LegSwitcherController from "../../app/javascript/controllers/leg_switcher_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

async function mount(html) {
  document.body.innerHTML = `<header class="pn-nav"></header>${html}`;
  application = Application.start();
  application.register("leg-switcher", LegSwitcherController);
  await flush();
}

const stop = (i) => `
  <button class="chip" data-leg-switcher-target="chip" data-stop="${i}"
          data-no="0${i + 1}" data-name="Stop ${i}" data-action="leg-switcher#jump"></button>
`;

const row = (i) => `
  <button class="row" data-leg-switcher-target="row" data-stop="${i}"
          data-action="leg-switcher#jump"></button>
`;

// Two stops, and a third band that returns to the first stop the way a gym finale does.
const leg = `
  <div class="pn-legsw-host" data-controller="leg-switcher">
    <div class="bar" data-leg-switcher-target="bar">
      <div data-leg-switcher-target="rail">${stop(0)}${stop(1)}</div>
      <button class="prev" data-leg-switcher-target="prevArrow" data-action="leg-switcher#goPrev"></button>
      <button class="toggle" data-leg-switcher-target="sheetToggle" aria-expanded="false"
              data-action="leg-switcher#toggleSheet">
        <span data-leg-switcher-target="stopNo"></span>
        <span data-leg-switcher-target="stopName"></span>
        <span data-leg-switcher-target="position"></span>
      </button>
      <button class="next" data-leg-switcher-target="nextArrow" data-action="leg-switcher#goNext"></button>
      <div class="sheet">${row(0)}${row(1)}</div>
      <span class="seg" data-leg-switcher-target="seg"></span>
      <span class="seg" data-leg-switcher-target="seg"></span>
    </div>
    <div class="band" data-leg-switcher-target="band" data-stop="0"></div>
    <div class="band" data-leg-switcher-target="band" data-stop="1"></div>
    <div class="band" data-leg-switcher-target="band" data-stop="1"></div>
  </div>
`;

const all = (selector) => Array.from(document.querySelectorAll(selector));
const at = (selector, i) => all(selector)[i];
const bar = () => document.querySelector(".bar");
const text = (target) => document.querySelector(`[data-leg-switcher-target="${target}"]`).textContent;
const activeIndexes = (selector) =>
  all(selector).flatMap((el, i) => (el.classList.contains("is-active") ? [ i ] : []));

const setTop = (i, top) => {
  at(".band", i).getBoundingClientRect = () => ({ top, height: 0 });
};

const scroll = () => window.dispatchEvent(new Event("scroll"));

beforeEach(() => {
  document.body.innerHTML = "";
  window.scrollTo = vi.fn();
});

afterEach(() => {
  application?.stop();
});

describe("leg_switcher_controller", () => {
  it("marks the stop whose band sits under the sticky bars, meter and all", async () => {
    await mount(leg);
    setTop(0, 0);
    setTop(1, 500);
    setTop(2, 900);
    scroll();

    expect(activeIndexes(".chip")).toEqual([ 0 ]);
    expect(activeIndexes(".row")).toEqual([ 0 ]);
    expect(text("stopName")).toBe("Stop 0");
    expect(text("stopNo")).toBe("01");
    expect(text("position")).toBe("1/2");
    expect(at(".seg", 0).classList.contains("is-here")).toBe(true);
    expect(at(".seg", 1).classList.contains("is-done")).toBe(false);

    setTop(1, 10);
    scroll();

    expect(activeIndexes(".chip")).toEqual([ 1 ]);
    expect(text("position")).toBe("2/2");
    expect(at(".seg", 0).classList.contains("is-done")).toBe(true);
    expect(at(".seg", 1).classList.contains("is-here")).toBe(true);
  });

  it("keeps the stop a repeated band names, rather than counting bands", async () => {
    await mount(leg);
    setTop(0, 0);
    setTop(1, 0);
    setTop(2, 0);
    scroll();

    expect(text("position")).toBe("2/2");
    expect(activeIndexes(".chip")).toEqual([ 1 ]);
  });

  it("measures both sticky bars into the offsets the bands scroll clear of", async () => {
    await mount(leg);
    document.querySelector(".pn-nav").getBoundingClientRect = () => ({ height: 98 });
    bar().getBoundingClientRect = () => ({ height: 58 });
    scroll();

    const host = document.querySelector(".pn-legsw-host");
    expect(host.style.getPropertyValue("--pn-nav-h")).toBe("98px");
    expect(host.style.getPropertyValue("--pn-legsw-h")).toBe("58px");

    // 98 + 58 + 8 clearance + 12 spy line: a band head at 170 has just passed under.
    setTop(1, 170);
    setTop(2, 900);
    scroll();
    expect(activeIndexes(".chip")).toEqual([ 1 ]);
  });

  it("jumps from a chip or a sheet row, clearing the bars and never above the page top", async () => {
    await mount(leg);
    setTop(1, 640);

    at(".chip", 1).click();
    expect(window.scrollTo).toHaveBeenCalledWith({ top: 640 - 8, behavior: "instant" });
    expect(activeIndexes(".chip")).toEqual([ 1 ]);

    setTop(0, -100);
    at(".row", 0).click();
    expect(window.scrollTo).toHaveBeenLastCalledWith({ top: 0, behavior: "instant" });
    expect(activeIndexes(".row")).toEqual([ 0 ]);
  });

  it("steps between neighbouring stops, greying the arrow at each end", async () => {
    await mount(leg);
    setTop(0, 0);
    setTop(1, 500);
    setTop(2, 900);
    scroll();
    expect(at(".prev", 0).disabled).toBe(true);
    expect(at(".next", 0).disabled).toBe(false);

    at(".next", 0).click();
    expect(text("position")).toBe("2/2");
    expect(activeIndexes(".chip")).toEqual([ 1 ]);
    expect(at(".next", 0).disabled).toBe(true);

    at(".prev", 0).click();
    expect(text("position")).toBe("1/2");
    expect(at(".prev", 0).disabled).toBe(true);
  });

  // The greyed arrows are what a reader sees; the clamp is what holds if one is ever live.
  it("holds at the ends of the leg when an arrow is stepped past them", async () => {
    await mount(leg);
    const [ prev, next ] = [ document.querySelector(".prev"), document.querySelector(".next") ];

    prev.disabled = false;
    prev.click();
    expect(text("position")).toBe("1/2");

    next.click();
    next.disabled = false;
    next.click();
    expect(text("position")).toBe("2/2");
  });

  it("opens the sheet from the stepper and closes it on a jump", async () => {
    await mount(leg);
    const toggle = document.querySelector(".toggle");

    toggle.click();
    expect(bar().classList.contains("is-open")).toBe(true);
    expect(toggle.getAttribute("aria-expanded")).toBe("true");

    toggle.click();
    expect(bar().classList.contains("is-open")).toBe(false);
    expect(toggle.getAttribute("aria-expanded")).toBe("false");

    toggle.click();
    at(".row", 1).click();
    expect(bar().classList.contains("is-open")).toBe(false);
  });

  it("closes the sheet on a press outside it but not on one inside", async () => {
    await mount(leg);
    document.querySelector(".toggle").click();

    at(".chip", 0).dispatchEvent(new Event("pointerdown", { bubbles: true }));
    expect(bar().classList.contains("is-open")).toBe(true);

    at(".band", 0).dispatchEvent(new Event("pointerdown", { bubbles: true }));
    expect(bar().classList.contains("is-open")).toBe(false);
  });

  it("closes the sheet on Escape", async () => {
    await mount(`${leg.replace(
      'data-controller="leg-switcher"',
      'data-controller="leg-switcher" data-action="keydown.esc@window->leg-switcher#closeSheet"'
    )}`);
    document.querySelector(".toggle").click();

    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    expect(bar().classList.contains("is-open")).toBe(false);
  });

  // A one-stop leg renders the same bar with only the plate in it.
  const solo = `
    <div class="pn-legsw-host" data-controller="leg-switcher"
         data-action="keydown.esc@window->leg-switcher#closeSheet">
      <div class="bar pn-legsw--solo" data-leg-switcher-target="bar">
        <div class="pn-legsw__plate">28 Celadon City</div>
      </div>
      <div class="band" data-leg-switcher-target="band" data-stop="0"></div>
    </div>
  `;

  it("still measures the sticky offsets for a one-stop leg, and paints nothing", async () => {
    await mount(solo);
    document.querySelector(".pn-nav").getBoundingClientRect = () => ({ height: 66 });
    bar().getBoundingClientRect = () => ({ height: 62 });
    scroll();

    const host = document.querySelector(".pn-legsw-host");
    expect(host.style.getPropertyValue("--pn-nav-h")).toBe("66px");
    expect(host.style.getPropertyValue("--pn-legsw-h")).toBe("62px");
  });

  it("has nothing to open on a one-stop leg, so the sheet handlers stay quiet", async () => {
    await mount(solo);

    at(".band", 0).dispatchEvent(new Event("pointerdown", { bubbles: true }));
    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));

    expect(bar().classList.contains("is-open")).toBe(false);
  });

  it("detaches its listeners and the resize observer on disconnect", async () => {
    await mount(leg);
    const removeSpy = vi.spyOn(window, "removeEventListener");
    document.body.innerHTML = "";
    await flush();

    expect(removeSpy).toHaveBeenCalledWith("scroll", expect.any(Function));
    expect(removeSpy).toHaveBeenCalledWith("resize", expect.any(Function));
  });
});
