import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import ProgressToggleController from "../../app/javascript/controllers/progress_toggle_controller.js";
import { STORAGE_KEY } from "../../app/javascript/lib/progress_store.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

const ACTIONS =
  "click->progress-toggle#toggle keydown.enter->progress-toggle#toggle keydown.space->progress-toggle#toggle";

// Mirrors what the progress_toast helper renders: a pill that swallows its own clicks and a RETRY
// button that re-attempts the save.
const TOAST = `
  <span class="pn-wt-toast" data-action="click->progress-toggle#stop">
    <span class="pn-wt-toast__msg pn-wt-toast__msg--done">Potion collected</span>
    <span class="pn-wt-toast__msg pn-wt-toast__msg--todo">Potion un-ticked</span>
    <span class="pn-wt-toast__msg pn-wt-toast__msg--error">Couldn't save</span>
    <button type="button" class="pn-wt-toast__retry" data-action="click->progress-toggle#retry">RETRY</button>
  </span>
`;

const FIXTURE = `
  <div data-controller="progress-toggle" data-progress-toggle-game-value="yellow" data-progress-toggle-hint-ms-value="20">
    <div id="item" role="button" tabindex="0" aria-pressed="false"
         data-progress-toggle-target="item" data-kind="collected"
         data-progress-id="viridian-forest/step-1/item-0" data-action="${ACTIONS}">${TOAST}</div>
    <div id="hidden" role="button" tabindex="0" aria-pressed="false"
         data-progress-toggle-target="item" data-kind="collected"
         data-progress-id="viridian-forest/step-2/hidden-0" data-action="${ACTIONS}"></div>
    <div id="mon" role="button" tabindex="0" aria-pressed="false"
         data-progress-toggle-target="item" data-kind="caught"
         data-progress-id="010" data-action="${ACTIONS}"></div>
    <span id="caught-count" data-progress-toggle-target="count"
          data-kind="caught" data-progress-ids="010 011 016">0</span>
  </div>
`;

async function mount(html = FIXTURE) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("progress-toggle", ProgressToggleController);
  await flush();
}

const el = (id) => document.getElementById(id);
const isDone = (id) => el(id).classList.contains("is-done");
const stored = () => JSON.parse(localStorage.getItem(STORAGE_KEY));

beforeEach(() => {
  localStorage.clear();
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
  vi.restoreAllMocks();
});

describe("ticking", () => {
  it("marks an item done, presses it, and persists it", async () => {
    await mount();

    el("item").click();
    await flush();

    expect(isDone("item")).toBe(true);
    expect(el("item").getAttribute("aria-pressed")).toBe("true");
    expect(stored().collected.yellow["viridian-forest/step-1/item-0"]).toBe(true);
  });

  it("unticks on a second click", async () => {
    await mount();

    el("hidden").click();
    el("hidden").click();
    await flush();

    expect(isDone("hidden")).toBe(false);
    expect(stored().collected.yellow["viridian-forest/step-2/hidden-0"]).toBeUndefined();
  });

  it("files a caught Pokemon separately from a collected item", async () => {
    await mount();

    el("mon").click();
    await flush();

    expect(stored().caught.yellow["010"]).toBe(true);
    expect(stored().collected.yellow).toBeUndefined();
    expect(isDone("item")).toBe(false);
  });

  it("counts only what has been caught out of the ids it was given", async () => {
    await mount();

    expect(el("caught-count").textContent).toBe("0");

    el("mon").click();
    await flush();

    expect(el("caught-count").textContent).toBe("1");
  });

  it("restores what was ticked in an earlier visit", async () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: {}, caught: { yellow: { "010": true } } })
    );
    await mount();

    expect(isDone("mon")).toBe(true);
    expect(el("caught-count").textContent).toBe("1");
  });

  it("picks up another tab's tick", async () => {
    await mount();

    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: {}, caught: { yellow: { "011": true } } })
    );
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(el("caught-count").textContent).toBe("1");
  });
});

describe("toast", () => {
  it("confirms the click, then gets out of the way", async () => {
    await mount();

    el("item").click();
    await flush();
    expect(el("item").classList.contains("is-hinting")).toBe(true);

    await new Promise((resolve) => setTimeout(resolve, 40));
    expect(el("item").classList.contains("is-hinting")).toBe(false);
  });

  it("moves to whichever card was touched last", async () => {
    await mount();

    el("item").click();
    await flush();
    el("hidden").click();
    await flush();

    expect(el("item").classList.contains("is-hinting")).toBe(false);
    expect(el("hidden").classList.contains("is-hinting")).toBe(true);
  });

  it("cancels a pending toast when the controller goes away", async () => {
    await mount();
    const block = document.querySelector("[data-controller]");

    el("item").click();
    await flush();
    block.remove();
    await flush();
    await new Promise((resolve) => setTimeout(resolve, 40));

    expect(block.querySelector("#item").classList.contains("is-hinting")).toBe(true);
  });
});

describe("saving", () => {
  const breakSave = () =>
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("quota exceeded");
    });

  it("flags an error and leaves the tick untouched when the write fails", async () => {
    await mount();
    breakSave();

    el("item").click();
    await flush();

    expect(el("item").classList.contains("is-error")).toBe(true);
    expect(isDone("item")).toBe(false);
    expect(el("item").getAttribute("aria-pressed")).toBe("false");
  });

  it("retries the save from the toast, ticks the card, and clears the error", async () => {
    await mount();
    const setItem = breakSave();

    el("item").click();
    await flush();
    expect(el("item").classList.contains("is-error")).toBe(true);

    setItem.mockRestore();
    el("item").querySelector(".pn-wt-toast__retry").click();
    await flush();

    expect(el("item").classList.contains("is-error")).toBe(false);
    expect(isDone("item")).toBe(true);
    expect(stored().collected.yellow["viridian-forest/step-1/item-0"]).toBe(true);
  });

  it("swallows clicks on the toast so the pill never toggles the card", async () => {
    await mount();

    el("item").querySelector(".pn-wt-toast").click();
    await flush();

    expect(isDone("item")).toBe(false);
    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
  });
});

describe("keyboard", () => {
  it("ticks on Enter and on Space, and keeps Space from scrolling the page", async () => {
    await mount();

    el("item").dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true, cancelable: true }));
    await flush();
    expect(isDone("item")).toBe(true);

    const space = new KeyboardEvent("keydown", { key: " ", code: "Space", bubbles: true, cancelable: true });
    el("mon").dispatchEvent(space);
    await flush();

    expect(isDone("mon")).toBe(true);
    expect(space.defaultPrevented).toBe(true);
  });
});

describe("teardown", () => {
  it("stops listening for other tabs once it goes away", async () => {
    await mount();
    const block = document.querySelector("[data-controller]");

    block.remove();
    await flush();

    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: {}, caught: { yellow: { "010": true } } })
    );
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(block.querySelector("#mon").classList.contains("is-done")).toBe(false);
  });
});
