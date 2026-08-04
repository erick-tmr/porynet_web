import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import BodyCounterController from "../../app/javascript/controllers/body_counter_controller.js";
import { STORAGE_KEY } from "../../app/javascript/lib/progress_store.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

const FIXTURE = `
  <div id="row" data-controller="body-counter" data-body-counter-game-value="yellow"
       data-body-counter-dex-value="010" data-body-counter-covers-value='["010","020"]'>
    <button id="minus" type="button" data-action="body-counter#remove">-</button>
    <span data-body-counter-target="have">0</span>
    <button id="plus" type="button" data-action="body-counter#add">+</button>
    <span class="pn-wt-ldrow__prog"><span data-body-counter-target="have">0</span> /
      <span data-body-counter-target="want">2</span> CAUGHT</span>
  </div>
`;

async function mount(html = FIXTURE) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("body-counter", BodyCounterController);
  await flush();
}

const el = (id) => document.getElementById(id);
const have = () => el("row").querySelector("[data-body-counter-target='have']").textContent;
const isMet = () => el("row").classList.contains("is-met");
const want = () => el("row").querySelector("[data-body-counter-target='want']").textContent;
const stored = () => JSON.parse(localStorage.getItem(STORAGE_KEY));

beforeEach(() => {
  localStorage.clear();
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
  vi.restoreAllMocks();
});

describe("counting bodies", () => {
  it("starts empty and counts up to the quota", async () => {
    await mount();

    expect(have()).toBe("0");
    expect(isMet()).toBe(false);

    el("plus").click();
    expect(have()).toBe("1");
    expect(isMet()).toBe(false);

    el("plus").click();
    expect(have()).toBe("2");
    expect(isMet()).toBe(true);
  });

  it("never counts past the quota", async () => {
    await mount();

    el("plus").click();
    el("plus").click();
    el("plus").click();

    expect(have()).toBe("2");
    expect(stored().bodies.yellow["010"]).toBe(2);
  });

  it("never counts below zero", async () => {
    await mount();

    el("minus").click();

    expect(have()).toBe("0");
    expect(stored().bodies.yellow["010"]).toBeUndefined();
  });

  it("writes every slot that asks for the count", async () => {
    await mount();

    el("plus").click();

    const slots = el("row").querySelectorAll("[data-body-counter-target='have']");
    expect([...slots].map((slot) => slot.textContent)).toEqual(["1", "1"]);
  });

  it("restores a count saved earlier", async () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: {}, caught: {}, bodies: { yellow: { "010": 2 } } }),
    );

    await mount();

    expect(have()).toBe("2");
    expect(isMet()).toBe(true);
  });

  it("owes a single specimen when the species covers only itself", async () => {
    await mount(`
      <div id="row" data-controller="body-counter" data-body-counter-dex-value="010">
        <button id="plus" type="button" data-action="body-counter#add">+</button>
        <span data-body-counter-target="have">0</span>
      </div>
    `);

    el("plus").click();

    expect(have()).toBe("1");
    expect(isMet()).toBe(true);
    expect(stored().bodies.yellow["010"]).toBe(1);
  });
});

describe("keeping Oak in step", () => {
  it("registers the species as caught on the first body", async () => {
    await mount();

    el("plus").click();

    expect(stored().caught.yellow["010"]).toBe(true);
  });

  it("un-registers it when the last body goes", async () => {
    await mount();

    el("plus").click();
    el("minus").click();

    expect(stored().caught.yellow["010"]).toBeUndefined();
    expect(stored().bodies.yellow["010"]).toBeUndefined();
  });
});

describe("saving", () => {
  it("keeps the count unchanged and flags the row when localStorage refuses", async () => {
    await mount();
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("quota exceeded");
    });

    el("plus").click();

    expect(have()).toBe("0");
    expect(el("row").classList.contains("is-error")).toBe(true);
  });

  it("clears the error once a save lands", async () => {
    await mount();
    const setItem = vi.spyOn(Storage.prototype, "setItem").mockImplementationOnce(() => {
      throw new Error("nope");
    });

    el("plus").click();
    expect(el("row").classList.contains("is-error")).toBe(true);

    setItem.mockRestore();
    el("plus").click();

    expect(el("row").classList.contains("is-error")).toBe(false);
    expect(have()).toBe("1");
  });
});

describe("clicks", () => {
  it("keeps a stepper click inside the stepper, so the card around it never toggles", async () => {
    const outer = [];
    await mount(`
      <div id="card">
        <div id="row" data-controller="body-counter" data-body-counter-dex-value="010"
             data-body-counter-covers-value='["010","020"]' data-action="click->body-counter#stop">
          <button id="plus" type="button" data-action="body-counter#add">+</button>
          <span data-body-counter-target="have">0</span>
        </div>
      </div>
    `);
    el("card").addEventListener("click", () => outer.push("card"));

    el("plus").click();

    expect(have()).toBe("1");
    expect(outer).toEqual([]);
  });
});

describe("staying in sync", () => {
  it("picks up a change made in another tab", async () => {
    await mount();

    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: {}, caught: {}, bodies: { yellow: { "010": 2 } } }),
    );
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(have()).toBe("2");
    expect(isMet()).toBe(true);
  });

  it("stops listening once disconnected", async () => {
    await mount();
    const row = el("row");

    row.remove();
    await flush();

    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: {}, caught: {}, bodies: { yellow: { "010": 2 } } }),
    );
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(row.querySelector("[data-body-counter-target='have']").textContent).toBe("0");
  });
});

describe("crediting stages you already own", () => {
  it("drops the quota when a covered evolution is already registered", async () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: {}, caught: { yellow: { "020": true } }, bodies: {} }),
    );

    await mount();

    expect(want()).toBe("1");
    el("plus").click();
    expect(isMet()).toBe(true);
  });

  it("still owes both while only the base is registered", async () => {
    await mount();

    el("plus").click();

    expect(want()).toBe("2");
    expect(have()).toBe("1");
    expect(isMet()).toBe(false);
  });
});
