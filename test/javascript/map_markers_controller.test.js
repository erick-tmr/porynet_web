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
    <button id="route-toggle" class="pn-mm-toggle"
            data-map-markers-target="routeToggle" data-action="click->map-markers#toggleRoute"></button>
    <span id="counter" data-map-markers-target="counterDone">0</span>

    <div id="canvas" data-map-markers-target="canvas" data-action="click->map-markers#dismiss">
      <div id="layer" data-map-markers-target="layer">
        <div id="m-trainer" class="pn-mm" data-map-markers-target="marker" data-role="marker"
             data-marker-id="trainer-30-33" data-cat="trainer" data-x="89.7" data-y="69.8" data-lane="0">
          <button id="hit-trainer" class="pn-mm__hit" data-action="click->map-markers#hit" aria-pressed="false"></button>
        </div>
        <div id="m-npc" class="pn-mm" data-map-markers-target="marker" data-role="marker"
             data-marker-id="npc-technology" data-cat="npc" data-x="57.5" data-y="80.5" data-lane="-2">
          <button id="hit-npc" class="pn-mm__hit" data-action="click->map-markers#hit"></button>
        </div>
        <div id="m-hidden" class="pn-mm" data-map-markers-target="marker" data-role="marker"
             data-marker-id="hidden-16-42" data-cat="hidden" data-x="48.5" data-y="88.5" data-lane="1">
          <button id="hit-hidden" class="pn-mm__hit" data-action="click->map-markers#hit" aria-pressed="false"></button>
        </div>
        <div id="m-exit" class="pn-mm" data-map-markers-target="marker" data-role="marker"
             data-marker-id="exit-15-47" data-cat="exit" data-x="50" data-y="99" data-lane="0">
          <button id="hit-exit" class="pn-mm__hit" data-action="click->map-markers#hit"></button>
          <div id="hint-exit" class="pn-mm__hint"></div>
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

  it("sends a label's row out signed and its leader line's length unsigned", async () => {
    await mount();

    expect(el("m-npc").style.getPropertyValue("--lane")).toBe("-2");
    expect(el("m-npc").style.getPropertyValue("--lane-rise")).toBe("2");
    expect(el("m-hidden").style.getPropertyValue("--lane-rise")).toBe("1");
  });

  it("flags a nudged label so it gets a leader line back to its pin", async () => {
    await mount();

    expect(has("m-hidden", "has-lane")).toBe(true); // lane 1
    expect(has("m-npc", "has-lane")).toBe(true); // lane -2
    expect(has("m-trainer", "has-lane")).toBe(false); // lane 0
  });

  it("points the leader line up for a label dealt above its pin", async () => {
    await mount();

    expect(has("m-npc", "has-lane--up")).toBe(true); // lane -2
    expect(has("m-hidden", "has-lane--up")).toBe(false); // lane 1
    expect(has("m-trainer", "has-lane--up")).toBe(false); // lane 0
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

  it("closes the hint when the same signpost is clicked again", async () => {
    await mount();

    el("hit-exit").click();
    await flush();
    expect(has("m-exit", "is-selected")).toBe(true);

    el("hit-exit").click();
    await flush();
    expect(has("m-exit", "is-selected")).toBe(false);
  });

  // A tickable marker's hint reports whether it is done, and the click that marks it done is
  // always the second one on it. Closing on that click left the "beaten" half of the popover with
  // no way to be seen at all: every click that opened a hint was a click that had just unticked.
  it("keeps a tickable marker's hint up so it can report the tick that click just made", async () => {
    await mount();

    el("hit-trainer").click();
    await flush();
    expect(has("m-trainer", "is-selected")).toBe(true);
    expect(has("m-trainer", "is-done")).toBe(true);

    el("hit-trainer").click();
    await flush();
    expect(has("m-trainer", "is-selected")).toBe(true);
    expect(has("m-trainer", "is-done")).toBe(false);
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

  it("dismisses the hint when the hint popup itself is clicked", async () => {
    await mount();

    el("hit-exit").click();
    await flush();
    expect(has("m-exit", "is-selected")).toBe(true);

    el("hint-exit").click();
    await flush();
    expect(has("m-exit", "is-selected")).toBe(false);
  });

  it("keeps the hint up when the pin that raised it is what got clicked", async () => {
    await mount();

    // The click on a pin bubbles to the canvas dismiss handler too, but a pin is left to #hit,
    // so opening a hint never immediately clears itself.
    el("hit-exit").click();
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

// The popover is fixed to the window and placed from the pin's own box, so the map's frame (which
// has to clip, for a wide map to scroll inside it) can no longer cut its top off. jsdom does no
// layout, so both boxes are stubbed: the pin is the zero-sized point a marker is, the hint is the
// rendered popover. The window is jsdom's default 1024x768.
describe("hint placement", () => {
  const pinAt = (node, x, y) => {
    node.getBoundingClientRect = () => ({ left: x, right: x, top: y, bottom: y, width: 0, height: 0 });
  };
  const hintSized = (node, width, height) => {
    node.getBoundingClientRect = () => ({ left: 0, right: width, top: 0, bottom: height, width, height });
  };
  const placed = () => ({
    x: el("hint-exit").style.getPropertyValue("--hint-x"),
    y: el("hint-exit").style.getPropertyValue("--hint-y"),
  });

  const open = async (x, y, width = 200, height = 100) => {
    await mount();
    pinAt(el("m-exit"), x, y);
    hintSized(el("hint-exit"), width, height);
    el("hit-exit").click();
    await flush();
  };

  it("centres the popover on its pin and sits it above the pin", async () => {
    await open(500, 400);

    expect(placed()).toEqual({ x: "400px", y: "274px" }); // 500 - 200 / 2, 400 - 26 - 100
  });

  it("drops the popover under a pin with no room above it", async () => {
    await open(500, 60);

    expect(placed()).toEqual({ x: "400px", y: "86px" }); // 60 + 26
  });

  it("holds a popover raised by a pin on the map's left edge inside the window", async () => {
    await open(10, 400);

    expect(placed().x).toBe("12px");
  });

  it("holds a popover raised by a pin on the map's right edge inside the window", async () => {
    await open(1020, 400);

    expect(placed().x).toBe("812px"); // 1024 - 200 - 12
  });

  it("holds a popover too tall for the space under its pin inside the window", async () => {
    await open(500, 60, 200, 700);

    expect(placed().y).toBe("56px"); // 768 - 700 - 12
  });

  it("keeps the popover on its pin while the page scrolls", async () => {
    await open(500, 400);

    pinAt(el("m-exit"), 500, 250);
    window.dispatchEvent(new Event("scroll"));
    await flush();

    expect(placed().y).toBe("124px"); // 250 - 26 - 100
  });

  it("leaves a dismissed popover alone when the page scrolls", async () => {
    await open(500, 400);

    el("layer").click();
    await flush();
    pinAt(el("m-exit"), 500, 250);
    window.dispatchEvent(new Event("scroll"));
    await flush();

    expect(placed().y).toBe("274px");
  });

  it("stops following the page once the controller disconnects", async () => {
    await open(500, 400);
    const marker = el("m-exit");
    const hint = el("hint-exit");

    el("block").remove(); // triggers disconnect -> the scroll listener goes with it
    await flush();
    pinAt(marker, 500, 250);
    window.dispatchEvent(new Event("scroll"));
    await flush();

    expect(hint.style.getPropertyValue("--hint-y")).toBe("274px");
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

  // The overview starts without the route on it: every step already carries its own crop of this
  // map with just that step's leg drawn, so all eight legs at once is for the reader who asks.
  it("starts unrouted and toggles on and off again without touching the labels", async () => {
    await mount();

    expect(has("block", "is-routed")).toBe(false);
    expect(has("route-toggle", "is-on")).toBe(false);
    expect(has("block", "is-labelled")).toBe(true);

    el("route-toggle").click();
    await flush();
    expect(has("block", "is-routed")).toBe(true);
    expect(el("route-toggle").getAttribute("aria-pressed")).toBe("true");
    expect(has("block", "is-labelled")).toBe(true);

    el("route-toggle").click();
    await flush();
    expect(has("block", "is-routed")).toBe(false);
  });
});
