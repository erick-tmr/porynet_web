import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import LeaveStandingController from "../../app/javascript/controllers/leave_standing_controller.js";
import { STORAGE_KEY } from "../../app/javascript/lib/progress_store.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

// Two of the four cards, enough to prove the sync and the inverse count. Progress ids mirror the
// exact keys the annotated maps tick, which is the whole point of the wiring.
const GRASS = "route-24/trainer-5-20";
const MISTY = "cerulean-city-gym/trainer-4-2";

const card = (id) => `
  <article data-leave-standing-target="card" data-progress-id="${id}">
    <button type="button" class="pn-ls-card__btn" aria-pressed="false"
            data-action="click->leave-standing#toggle"></button>
  </article>
`;

const FIXTURE = `
  <section data-controller="leave-standing" data-leave-standing-game-value="yellow">
    <span data-leave-standing-target="standing">2</span>
    ${card(GRASS)}
    ${card(MISTY)}
  </section>
`;

async function mount(html = FIXTURE) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("leave-standing", LeaveStandingController);
  await flush();
}

const cardEl = (id) => document.querySelector(`[data-progress-id="${id}"]`);
const btn = (id) => cardEl(id).querySelector(".pn-ls-card__btn");
const isDefeated = (id) => cardEl(id).classList.contains("is-defeated");
const standing = () => document.querySelector("[data-leave-standing-target='standing']").textContent;
const stored = () => JSON.parse(localStorage.getItem(STORAGE_KEY));

beforeEach(() => {
  localStorage.clear();
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
  vi.restoreAllMocks();
});

describe("initial render", () => {
  it("starts with every Trainer standing and none pressed", async () => {
    await mount();

    expect(isDefeated(GRASS)).toBe(false);
    expect(btn(GRASS).getAttribute("aria-pressed")).toBe("false");
    expect(standing()).toBe("2");
  });

  it("restores a Trainer beaten in an earlier visit and drops the count", async () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: { yellow: { [GRASS]: true } }, caught: {} })
    );
    await mount();

    expect(isDefeated(GRASS)).toBe(true);
    expect(btn(GRASS).getAttribute("aria-pressed")).toBe("true");
    expect(standing()).toBe("1");
  });
});

describe("toggling a card", () => {
  it("marks the Trainer defeated, drops the count, and persists the shared key", async () => {
    await mount();

    btn(GRASS).click();
    await flush();

    expect(isDefeated(GRASS)).toBe(true);
    expect(btn(GRASS).getAttribute("aria-pressed")).toBe("true");
    expect(standing()).toBe("1");
    expect(stored().collected.yellow[GRASS]).toBe(true);
  });

  it("brings the Trainer back on a second click", async () => {
    await mount();

    btn(MISTY).click();
    btn(MISTY).click();
    await flush();

    expect(isDefeated(MISTY)).toBe(false);
    expect(standing()).toBe("2");
    expect(stored().collected.yellow[MISTY]).toBeUndefined();
  });
});

describe("staying in sync with the maps", () => {
  it("flips a card when its pin is ticked elsewhere", async () => {
    await mount();

    // What map_markers_controller does when its trainer pin is clicked: writes the same key.
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: { yellow: { [MISTY]: true } }, caught: {} })
    );
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(isDefeated(MISTY)).toBe(true);
    expect(standing()).toBe("1");
  });

  it("stops listening once the section is gone", async () => {
    await mount();
    const section = document.querySelector("[data-controller]");
    section.remove();
    await flush();

    // A late external change must not throw or touch the detached card.
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: { yellow: { [GRASS]: true } }, caught: {} })
    );
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(section.querySelector(`[data-progress-id="${GRASS}"]`).classList.contains("is-defeated")).toBe(false);
  });
});

describe("when the write fails", () => {
  it("flags the card and leaves it standing", async () => {
    await mount();
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("quota exceeded");
    });

    btn(GRASS).click();
    await flush();

    expect(cardEl(GRASS).classList.contains("is-error")).toBe(true);
    expect(isDefeated(GRASS)).toBe(false);
    expect(btn(GRASS).getAttribute("aria-pressed")).toBe("false");
    expect(standing()).toBe("2");
    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
  });
});
