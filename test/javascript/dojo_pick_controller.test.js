import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import DojoPickController from "../../app/javascript/controllers/dojo_pick_controller.js";
import { STORAGE_KEY } from "../../app/javascript/lib/progress_store.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

const ACTIONS =
  "click->dojo-pick#toggle keydown.enter->dojo-pick#toggle keydown.space->dojo-pick#toggle";

const card = (id, dex, name) => `
  <div id="${id}" class="pn-wt-pick__card" role="button" tabindex="0" aria-pressed="false"
       data-dojo-pick-target="item" data-kind="caught" data-progress-id="${dex}"
       data-pick-name="${name}" data-action="${ACTIONS}"></div>
`;

const FIXTURE = `
  <div class="pn-wt-pick" data-controller="dojo-pick" data-dojo-pick-game-value="yellow">
    ${card("lee", "106", "Hitmonlee")}
    ${card("chan", "107", "Hitmonchan")}
    <div id="state" data-dojo-pick-target="state" hidden>
      <span>Marked: <b data-dojo-pick-target="name"></b> taken.</span>
      <button type="button" id="undo" data-action="dojo-pick#clear">UNDO</button>
    </div>
  </div>
`;

async function mount(html = FIXTURE) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("dojo-pick", DojoPickController);
  await flush();
}

const el = (id) => document.getElementById(id);
const classes = (id) => [...el(id).classList];
const stored = () => JSON.parse(localStorage.getItem(STORAGE_KEY));

beforeEach(() => {
  localStorage.clear();
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
  vi.restoreAllMocks();
});

describe("picking a ball", () => {
  it("starts with neither picked and the state line away", async () => {
    await mount();

    expect(classes("lee")).toEqual(["pn-wt-pick__card"]);
    expect(classes("chan")).toEqual(["pn-wt-pick__card"]);
    expect(el("state").hidden).toBe(true);
  });

  it("marks the picked Pokemon caught and names it in the state line", async () => {
    await mount();

    el("lee").click();
    await flush();

    expect(classes("lee")).toContain("is-done");
    expect(el("lee").getAttribute("aria-pressed")).toBe("true");
    expect(el("state").hidden).toBe(false);
    expect(document.querySelector("[data-dojo-pick-target='name']").textContent).toBe("Hitmonlee");
    expect(stored().caught.yellow["106"]).toBe(true);
    expect(stored().bodies.yellow["106"]).toBe(1);
  });

  it("shuts the other ball", async () => {
    await mount();

    el("lee").click();
    await flush();

    expect(classes("chan")).toContain("is-gone");
    expect(el("chan").getAttribute("aria-pressed")).toBe("false");
  });

  // The game only ever hands over one, so this is a radio: the second ball is not an addition.
  it("moves the pick rather than adding to it", async () => {
    await mount();

    el("lee").click();
    await flush();
    el("chan").click();
    await flush();

    expect(classes("lee")).toContain("is-gone");
    expect(classes("chan")).toContain("is-done");
    expect(stored().caught.yellow["106"]).toBeUndefined();
    expect(stored().caught.yellow["107"]).toBe(true);
  });

  it("puts the ball back when its own card is clicked again", async () => {
    await mount();

    el("lee").click();
    await flush();
    el("lee").click();
    await flush();

    expect(classes("lee")).toEqual(["pn-wt-pick__card"]);
    expect(classes("chan")).toEqual(["pn-wt-pick__card"]);
    expect(el("state").hidden).toBe(true);
    expect(stored().caught.yellow["106"]).toBeUndefined();
  });

  it("undoes the pick from the state line", async () => {
    await mount();

    el("lee").click();
    await flush();
    el("undo").click();
    await flush();

    expect(classes("lee")).toEqual(["pn-wt-pick__card"]);
    expect(el("state").hidden).toBe(true);
  });

  it("answers Enter and Space like a button", async () => {
    await mount();

    el("chan").dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
    await flush();
    expect(classes("chan")).toContain("is-done");

    el("chan").dispatchEvent(new KeyboardEvent("keydown", { key: " ", bubbles: true }));
    await flush();
    expect(classes("chan")).not.toContain("is-done");
  });
});

describe("reading state back", () => {
  it("restores a pick made in an earlier visit", async () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: {}, caught: { yellow: { "107": true } }, bodies: {} })
    );
    await mount();

    expect(classes("chan")).toContain("is-done");
    expect(classes("lee")).toContain("is-gone");
    expect(document.querySelector("[data-dojo-pick-target='name']").textContent).toBe("Hitmonchan");
  });

  // Catching the other half by trade is the only way to hold both, and then neither ball is the
  // one you walked past, so nothing greys out.
  it("leaves both standing when both are already caught", async () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: {}, caught: { yellow: { "106": true, "107": true } }, bodies: {} })
    );
    await mount();

    expect(classes("lee")).toContain("is-done");
    expect(classes("chan")).not.toContain("is-gone");
  });

  it("picks up a tick made somewhere else on the page", async () => {
    await mount();

    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: {}, caught: { yellow: { "106": true } }, bodies: {} })
    );
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(classes("lee")).toContain("is-done");
  });

  it("stops listening once it goes away", async () => {
    await mount();
    document.querySelector("[data-controller]").remove();
    await flush();

    expect(() => window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY })))
      .not.toThrow();
  });
});

describe("when the save is refused", () => {
  const breakSave = () =>
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("quota exceeded");
    });

  it("leaves the room as it was and says so", async () => {
    await mount();
    breakSave();

    el("lee").click();
    await flush();

    expect(classes("lee")).toEqual(["pn-wt-pick__card"]);
    expect(document.querySelector(".pn-wt-pick").classList.contains("is-error")).toBe(true);
    expect(el("state").hidden).toBe(false);
  });

  it("clears the warning once a save lands", async () => {
    await mount();
    const save = breakSave();

    el("lee").click();
    await flush();
    save.mockRestore();
    el("lee").click();
    await flush();

    expect(document.querySelector(".pn-wt-pick").classList.contains("is-error")).toBe(false);
    expect(classes("lee")).toContain("is-done");
  });
});
