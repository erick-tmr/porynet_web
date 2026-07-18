import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import LegSwitcherController from "../../app/javascript/controllers/leg_switcher_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

async function mount(html) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("leg-switcher", LegSwitcherController);
  await flush();
}

const chipActive = (slug) =>
  document.querySelector(`[data-role="chip"][data-slug="${slug}"]`).classList.contains("is-active");

const setTop = (slug, top) => {
  document.querySelector(`[data-role="band"][data-slug="${slug}"]`).getBoundingClientRect = () => ({ top });
};

beforeEach(() => {
  document.body.innerHTML = "";
  window.scrollTo = vi.fn();
  Element.prototype.scrollIntoView = vi.fn();
});

afterEach(() => {
  application?.stop();
});

const twoBands = `
  <div data-controller="leg-switcher">
    <button data-role="chip" data-leg-switcher-target="chip" data-slug="a" data-action="leg-switcher#jump"></button>
    <button data-role="chip" data-leg-switcher-target="chip" data-slug="b" data-action="leg-switcher#jump"></button>
    <div data-role="band" data-leg-switcher-target="band" data-slug="a"></div>
    <div data-role="band" data-leg-switcher-target="band" data-slug="b"></div>
  </div>
`;

describe("leg_switcher_controller", () => {
  it("highlights the band currently under the sticky bars on scroll", async () => {
    await mount(twoBands);
    setTop("a", 0);
    setTop("b", 500);
    window.dispatchEvent(new Event("scroll"));

    expect(chipActive("a")).toBe(true);
    expect(chipActive("b")).toBe(false);

    setTop("b", 100);
    window.dispatchEvent(new Event("scroll"));

    expect(chipActive("b")).toBe(true);
    expect(chipActive("a")).toBe(false);
  });

  it("smooth-scrolls to the matching band on chip click, ignoring unknown chips", async () => {
    await mount(twoBands);
    const band = document.querySelector('[data-role="band"][data-slug="b"]');

    document.querySelector('[data-role="chip"][data-slug="b"]').click();
    expect(band.scrollIntoView).toHaveBeenCalledWith({ behavior: "smooth", block: "start" });

    const ghost = document.querySelector('[data-role="chip"][data-slug="a"]');
    ghost.dataset.slug = "nope";
    ghost.click();
    expect(band.scrollIntoView).toHaveBeenCalledTimes(1);
  });

  it("does nothing when the leg has no bands", async () => {
    await mount(`
      <div data-controller="leg-switcher">
        <button data-role="chip" data-leg-switcher-target="chip" data-slug="a"></button>
      </div>
    `);
    window.dispatchEvent(new Event("scroll"));

    expect(chipActive("a")).toBe(false);
  });

  it("detaches the scroll listener on disconnect", async () => {
    await mount(twoBands);
    const removeSpy = vi.spyOn(window, "removeEventListener");
    document.body.innerHTML = "";
    await flush();
    expect(removeSpy).toHaveBeenCalledWith("scroll", expect.any(Function));
  });
});
