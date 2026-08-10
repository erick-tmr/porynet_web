import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import SectionFoldController from "../../app/javascript/controllers/section_fold_controller.js";
import { SCHEMA_VERSION, STORAGE_KEY } from "../../app/javascript/lib/section_store.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

// Two boxes on one stop, as a leg page renders them: each folds on its own key.
const FIXTURE = `
  <section id="grass" class="pn-wt-catchsec is-open" data-controller="section-fold"
           data-section-fold-game-value="yellow" data-section-fold-id-value="route-24/grass">
    <button id="grass-head" data-section-fold-target="toggle" data-action="section-fold#toggle"
            aria-expanded="true">Tall grass</button>
    <div id="grass-body" data-section-fold-target="body">cards</div>
  </section>
  <section id="rod" class="pn-wt-catchsec is-open" data-controller="section-fold"
           data-section-fold-game-value="yellow" data-section-fold-id-value="route-24/super-rod">
    <button id="rod-head" data-section-fold-target="toggle" data-action="section-fold#toggle"
            aria-expanded="true">Super Rod</button>
    <div id="rod-body" data-section-fold-target="body">cards</div>
  </section>
`;

async function mount(html = FIXTURE) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("section-fold", SectionFoldController);
  await flush();
}

const el = (id) => document.getElementById(id);

const seed = (folds) =>
  localStorage.setItem(STORAGE_KEY, JSON.stringify({ v: SCHEMA_VERSION, folds: folds }));

const stored = () => JSON.parse(localStorage.getItem(STORAGE_KEY));

beforeEach(() => {
  localStorage.clear();
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
  vi.restoreAllMocks();
});

describe("section_fold_controller", () => {
  it("leaves every box open when nothing has been folded, and marks itself ready", async () => {
    await mount();

    expect(el("grass-body").hidden).toBe(false);
    expect(el("grass").classList.contains("is-open")).toBe(true);
    expect(el("grass").classList.contains("is-ready")).toBe(true);
    expect(el("grass-head").getAttribute("aria-expanded")).toBe("true");
  });

  it("folds on click, writing down that one box and leaving its neighbour alone", async () => {
    await mount();

    el("grass-head").click();
    await flush();

    expect(el("grass-body").hidden).toBe(true);
    expect(el("grass").classList.contains("is-open")).toBe(false);
    expect(el("grass-head").getAttribute("aria-expanded")).toBe("false");
    expect(stored().folds.yellow).toEqual({ "route-24/grass": false });

    expect(el("rod-body").hidden).toBe(false);
    expect(el("rod").classList.contains("is-open")).toBe(true);
  });

  it("comes back folded on the next visit", async () => {
    seed({ yellow: { "route-24/grass": false } });
    await mount();

    expect(el("grass-body").hidden).toBe(true);
    expect(el("grass").classList.contains("is-open")).toBe(false);
    expect(el("grass-head").getAttribute("aria-expanded")).toBe("false");
    expect(el("rod-body").hidden).toBe(false);
  });

  it("clears the box from storage when it is opened again", async () => {
    seed({ yellow: { "route-24/grass": false } });
    await mount();

    el("grass-head").click();
    await flush();

    expect(el("grass-body").hidden).toBe(false);
    expect(stored().folds.yellow).toEqual({});
  });

  it("follows a fold made in another tab", async () => {
    await mount();

    seed({ yellow: { "route-24/grass": false } });
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(el("grass-body").hidden).toBe(true);
    expect(el("rod-body").hidden).toBe(false);
  });

  it("still folds when the write fails, so a full storage cannot wedge the box open", async () => {
    await mount();
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("QuotaExceededError");
    });

    el("grass-head").click();
    await flush();

    expect(el("grass-body").hidden).toBe(true);
    expect(el("grass").classList.contains("is-open")).toBe(false);
  });

  it("stops listening once it leaves the page", async () => {
    await mount();
    const body = el("grass-body");

    el("grass").remove();
    await flush();

    seed({ yellow: { "route-24/grass": false } });
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(body.hidden).toBe(false);
  });
});
