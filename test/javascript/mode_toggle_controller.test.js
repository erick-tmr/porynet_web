import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import ModeToggleController from "../../app/javascript/controllers/mode_toggle_controller.js";
import { SCHEMA_VERSION, STORAGE_KEY } from "../../app/javascript/lib/mode_store.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

const FIXTURE = `
  <div id="root" class="porynet" data-controller="mode-toggle" data-mode-toggle-game-value="yellow">
    <button id="sw-living" type="button" aria-pressed="false"
            data-mode-toggle-target="switch" data-mode="living" data-action="mode-toggle#toggle"></button>
    <button id="sw-oak" type="button" aria-pressed="false"
            data-mode-toggle-target="switch" data-mode="oak" data-action="mode-toggle#toggle"></button>
    <button id="chip-oak" type="button" aria-pressed="false"
            data-mode-toggle-target="switch" data-mode="oak" data-action="mode-toggle#toggle"></button>
  </div>
`;

async function mount(html = FIXTURE) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("mode-toggle", ModeToggleController);
  await flush();
}

const el = (id) => document.getElementById(id);
const root = () => el("root");
const isOn = (mode) => root().classList.contains(`pn-mode-${mode}-on`);
const pressed = (id) => el(id).getAttribute("aria-pressed");
const stored = () => JSON.parse(localStorage.getItem(STORAGE_KEY));

beforeEach(() => {
  localStorage.clear();
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
  vi.restoreAllMocks();
});

describe("mode_toggle_controller", () => {
  it("leaves both modes off when nothing has been stored", async () => {
    await mount();

    expect(isOn("living")).toBe(false);
    expect(isOn("oak")).toBe(false);
    expect(pressed("sw-living")).toBe("false");
    expect(pressed("sw-oak")).toBe("false");
  });

  it("switches one mode on without touching the other, and persists it", async () => {
    await mount();

    el("sw-oak").click();
    await flush();

    expect(isOn("oak")).toBe(true);
    expect(isOn("living")).toBe(false);
    expect(pressed("sw-oak")).toBe("true");
    expect(pressed("sw-living")).toBe("false");
    expect(stored().oak.yellow).toBe(true);
  });

  it("moves every switch for the same mode together, wherever it sits on the page", async () => {
    await mount();

    el("chip-oak").click();
    await flush();

    expect(pressed("sw-oak")).toBe("true");
    expect(pressed("chip-oak")).toBe("true");
  });

  it("switches back off", async () => {
    await mount();

    el("sw-living").click();
    await flush();
    el("sw-living").click();
    await flush();

    expect(isOn("living")).toBe(false);
    expect(stored().living.yellow).toBe(false);
  });

  it("restores what was stored, for this game only", async () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: SCHEMA_VERSION, living: { red: true }, oak: { yellow: true } }),
    );

    await mount();

    expect(isOn("oak")).toBe(true);
    expect(isOn("living")).toBe(false);
  });

  it("still works for the session when the write cannot land", async () => {
    await mount();
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("QuotaExceededError");
    });

    el("sw-oak").click();
    await flush();

    expect(isOn("oak")).toBe(true);
  });

  it("follows another tab switching a mode", async () => {
    await mount();

    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: SCHEMA_VERSION, living: { yellow: true }, oak: {} }),
    );
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(isOn("living")).toBe(true);
  });

  it("lets go of the store once it leaves the page", async () => {
    await mount();
    const detached = root();

    detached.remove();
    await flush();

    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: SCHEMA_VERSION, living: {}, oak: { yellow: true } }),
    );
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(detached.classList.contains("pn-mode-oak-on")).toBe(false);
  });
});
