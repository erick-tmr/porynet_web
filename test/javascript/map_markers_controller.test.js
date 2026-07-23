import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import MapMarkersController from "../../app/javascript/controllers/map_markers_controller.js";
import { STORAGE_KEY, load, save, toggle } from "../../app/javascript/lib/progress_store.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

// One of each shape: a lettered trainer, an un-tickable NPC, an un-tickable exit, and a hidden
// item that also has a legend row, so the row and the pin can be checked against the same id.
const FIXTURE = `
  <div id="block" data-controller="map-markers"
       data-map-markers-game-value="yellow"
       data-map-markers-map-value="viridian-forest"
       data-map-markers-native-w-value="544">
    <button id="pill-all" class="pn-mm-pill" data-cat="all"
            data-map-markers-target="filter" data-action="click->map-markers#filter"></button>
    <button id="pill-trainer" class="pn-mm-pill" data-cat="trainer"
            data-map-markers-target="filter" data-action="click->map-markers#filter"></button>
    <button id="toggle" class="pn-mm-toggle"
            data-map-markers-target="labelToggle" data-action="click->map-markers#toggleLabels"></button>
    <span id="counter" data-map-markers-target="counterDone">0</span>

    <div id="canvas" data-map-markers-target="canvas" data-action="click->map-markers#dismiss">
      <div id="layer" data-map-markers-target="layer">
        <div id="m-trainer" class="pn-mm" data-map-markers-target="marker" data-role="marker"
             data-marker-id="trainer-30-33" data-cat="trainer" data-x="89.7" data-y="69.8" data-lane="0">
          <button id="hit-trainer" data-action="click->map-markers#hit" aria-pressed="false"></button>
        </div>
        <div id="m-npc" class="pn-mm" data-map-markers-target="marker" data-role="marker"
             data-marker-id="npc-technology" data-cat="npc" data-x="57.5" data-y="80.5" data-lane="0">
          <button id="hit-npc" data-action="click->map-markers#hit"></button>
        </div>
        <div id="m-hidden" class="pn-mm" data-map-markers-target="marker" data-role="marker"
             data-marker-id="hidden-16-42" data-cat="hidden" data-x="48.5" data-y="88.5" data-lane="1">
          <button id="hit-hidden" data-action="click->map-markers#hit" aria-pressed="false"></button>
        </div>
        <div id="m-exit" class="pn-mm" data-map-markers-target="marker" data-role="marker"
             data-marker-id="exit-15-47" data-cat="exit" data-x="50" data-y="99" data-lane="0">
          <button id="hit-exit" data-action="click->map-markers#hit"></button>
        </div>
      </div>
    </div>

    <button id="row-hidden" class="pn-mm-legend__row" data-map-markers-target="legendRow"
            data-marker-id="hidden-16-42" data-cat="hidden"
            data-action="click->map-markers#hit"></button>
  </div>
`;

async function mount(html = FIXTURE) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("map-markers", MapMarkersController);
  await flush();
}

const el = (id) => document.getElementById(id);
const has = (id, cls) => el(id).classList.contains(cls);
const stored = () => JSON.parse(localStorage.getItem(STORAGE_KEY));

beforeEach(() => {
  localStorage.clear();
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("placement", () => {
  it("writes each marker's position and lane as custom properties", async () => {
    await mount();

    expect(el("m-trainer").style.getPropertyValue("--mx")).toBe("89.7%");
    expect(el("m-trainer").style.getPropertyValue("--my")).toBe("69.8%");
    expect(el("m-hidden").style.getPropertyValue("--lane")).toBe("1");
  });

  it("reveals the layer only once the markers have been placed", async () => {
    await mount();

    expect(has("layer", "is-ready")).toBe(true);
  });

  it("carries the map's native pixel width to the canvas", async () => {
    await mount();

    expect(el("canvas").style.getPropertyValue("--mm-native-w")).toBe("544px");
  });

  it("coexists with a map that has no marker layer", async () => {
    await mount(`<div data-controller="map-markers" data-map-markers-map-value="route-1"></div>`);

    expect(document.querySelector(".is-ready")).toBeNull();
  });
});

describe("ticking", () => {
  it("marks a pin done, presses it, counts it, and persists it", async () => {
    await mount();

    el("hit-trainer").click();
    await flush();

    expect(has("m-trainer", "is-done")).toBe(true);
    expect(el("hit-trainer").getAttribute("aria-pressed")).toBe("true");
    expect(el("counter").textContent).toBe("1");
    expect(stored().collected.yellow["viridian-forest/trainer-30-33"]).toBe(true);
  });

  it("unticks on a second click", async () => {
    await mount();

    el("hit-trainer").click();
    el("hit-trainer").click();
    await flush();

    expect(has("m-trainer", "is-done")).toBe(false);
    expect(el("counter").textContent).toBe("0");
    expect(stored().collected.yellow["viridian-forest/trainer-30-33"]).toBeUndefined();
  });

  it("ticks the pin and its legend row together, counting the pair once", async () => {
    await mount();

    el("row-hidden").click();
    await flush();

    expect(has("m-hidden", "is-done")).toBe(true);
    expect(has("row-hidden", "is-done")).toBe(true);
    expect(el("counter").textContent).toBe("1");
  });

  it("leaves an exit alone: a signpost is not a chore", async () => {
    await mount();

    el("hit-exit").click();
    await flush();

    expect(has("m-exit", "is-done")).toBe(false);
    expect(el("counter").textContent).toBe("0");
    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
  });

  it("leaves an NPC alone too: it raises a hint but never ticks", async () => {
    await mount();

    el("hit-npc").click();
    await flush();

    expect(has("m-npc", "is-selected")).toBe(true);
    expect(has("m-npc", "is-done")).toBe(false);
    expect(el("counter").textContent).toBe("0");
    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
  });

  it("restores what was ticked in an earlier visit", async () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: { yellow: { "viridian-forest/trainer-30-33": true } }, caught: {} })
    );
    await mount();

    expect(has("m-trainer", "is-done")).toBe(true);
    expect(el("counter").textContent).toBe("1");
  });

  it("picks up another tab's tick", async () => {
    await mount();

    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: 1, collected: { yellow: { "viridian-forest/hidden-16-42": true } }, caught: {} })
    );
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));
    await flush();

    expect(has("m-hidden", "is-done")).toBe(true);
    expect(el("counter").textContent).toBe("1");
  });
});

describe("hint", () => {
  it("raises a hint on click and keeps it up on its own", async () => {
    await mount();

    el("hit-exit").click();
    await flush();
    expect(has("m-exit", "is-selected")).toBe(true);

    // No timer: the hint stays until something dismisses it.
    await new Promise((resolve) => setTimeout(resolve, 40));
    expect(has("m-exit", "is-selected")).toBe(true);
  });

  it("moves the hint to whichever marker was touched last", async () => {
    await mount();

    el("hit-trainer").click();
    await flush();
    el("hit-hidden").click();
    await flush();

    expect(has("m-trainer", "is-selected")).toBe(false);
    expect(has("m-hidden", "is-selected")).toBe(true);
  });

  it("dismisses the hint when the bare map is clicked", async () => {
    await mount();

    el("hit-exit").click();
    await flush();
    expect(has("m-exit", "is-selected")).toBe(true);

    el("layer").click();
    await flush();
    expect(has("m-exit", "is-selected")).toBe(false);
  });

  it("keeps the hint up when the click lands on a marker, not the bare map", async () => {
    await mount();

    el("hit-exit").click();
    await flush();
    // A click bubbling up from a pin reaches the canvas too, but must not clear the hint #hit set.
    el("m-exit").click();
    await flush();

    expect(has("m-exit", "is-selected")).toBe(true);
  });

  it("stops reacting to stored progress once the controller disconnects", async () => {
    await mount();
    const pin = el("m-trainer");

    el("block").remove(); // triggers disconnect -> unsubscribe
    await flush();

    // A later store write must not reach the detached, no-longer-subscribed marker.
    save(toggle(load(), "collected", "yellow", "viridian-forest/trainer-30-33"));
    await flush();
    expect(pin.classList.contains("is-done")).toBe(false);
  });
});

describe("filters and labels", () => {
  it("shows one category at a time and marks the active pill", async () => {
    await mount();

    el("pill-trainer").click();
    await flush();

    expect(has("m-trainer", "is-filtered")).toBe(false);
    expect(has("m-hidden", "is-filtered")).toBe(true);
    expect(has("pill-trainer", "is-active")).toBe(true);
    expect(el("pill-trainer").getAttribute("aria-pressed")).toBe("true");
    expect(has("pill-all", "is-active")).toBe(false);
  });

  it("brings everything back", async () => {
    await mount();

    el("pill-trainer").click();
    await flush();
    el("pill-all").click();
    await flush();

    expect(has("m-hidden", "is-filtered")).toBe(false);
    expect(has("pill-all", "is-active")).toBe(true);
  });

  it("starts labelled and toggles off and on again", async () => {
    await mount();

    expect(has("block", "is-labelled")).toBe(true);
    expect(has("toggle", "is-on")).toBe(true);

    el("toggle").click();
    await flush();
    expect(has("block", "is-labelled")).toBe(false);
    expect(el("toggle").getAttribute("aria-pressed")).toBe("false");

    el("toggle").click();
    await flush();
    expect(has("block", "is-labelled")).toBe(true);
  });
});
