import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import MapJumpController from "../../app/javascript/controllers/map_jump_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

// One map block, with however many pins it draws. The real markup carries a great deal more; what
// the jump reads is the map's own name and, per pin, its key, its id and its category.
const block = (name, pins) => `
  <div class="pn-mm-block" data-controller="map-markers" data-map-markers-map-value="${name}">
    ${pins
      .map(
        ([key, id, cat]) => `
      <div data-role="marker" data-marker-key="${key}" data-marker-id="${id}" data-cat="${cat}"></div>`,
      )
      .join("")}
  </div>`;

const chip = (key, map) =>
  `<button class="pn-wt-mark" data-action="click->map-jump#go" data-mark-key="${key}"${
    map === undefined ? "" : ` data-mark-map="${map}"`
  }>${key}</button>`;

// Seafoam: a ladder wearing E13 at both ends, and an H1 on two floors that is a different hidden
// item on each. The page draws the floors in order, top down.
const SEAFOAM = `
  ${block("seafoam-b2f", [
    ["E13", "exit-13-7", "exit"],
    ["H1", "hidden-15-15", "hidden"],
  ])}
  ${block("seafoam-b3f", [
    ["E13", "exit-8-6", "exit"],
    ["H1", "hidden-9-16", "hidden"],
  ])}
  ${block("seafoam-b4f", [["E13", "exit-11-7", "exit"]])}
`;

async function mount(inner) {
  document.body.innerHTML = `<div id="page" data-controller="map-jump">${inner}</div>`;
  application = Application.start();
  application.register("map-jump", MapJumpController);
  await flush();
}

// scrollIntoView is stubbed on the prototype, so every element shares one mock and the calls have
// to be attributed by their receiver rather than read off a per-element spy.
let jumps;

const jumped = () => jumps.at(-1);

const click = (key) => document.querySelector(`[data-mark-key="${key}"]`).click();

// Stand-ins for each block's own map-markers controller, keyed by the map they draw, so a test can
// read back which pin each floor ended up showing.
function stubMaps() {
  const maps = {};
  document.querySelectorAll("[data-map-markers-map-value]").forEach((block) => {
    maps[block.dataset.mapMarkersMapValue] = { hintValue: "" };
  });
  application.getControllerForElementAndIdentifier = (element) =>
    maps[element.dataset.mapMarkersMapValue];
  return maps;
}

beforeEach(() => {
  document.body.innerHTML = "";
  jumps = [];
  Element.prototype.scrollIntoView = vi.fn(function (options) {
    jumps.push({ map: this.dataset.mapMarkersMapValue, options: options });
  });
});

afterEach(() => {
  application?.stop();
  vi.restoreAllMocks();
});

describe("map jump", () => {
  it("scrolls to the map that draws the pin the chip names", async () => {
    await mount(`${SEAFOAM}${chip("H1", "seafoam-b3f")}`);

    click("H1");

    expect(jumped()).toEqual({ map: "seafoam-b3f", options: { block: "start" } });
  });

  it("takes the first floor for a marker drawn at both ends of one staircase", async () => {
    await mount(`${SEAFOAM}${chip("E13", "seafoam-b4f")}`);

    click("E13");

    expect(jumped().map).toBe("seafoam-b2f");
  });

  it("takes the first floor when the chip names no map of its own", async () => {
    await mount(`${SEAFOAM}${chip("H1")}`);

    click("H1");

    expect(jumped().map).toBe("seafoam-b2f");
  });

  it("takes the first floor when the chip names a map that does not draw it", async () => {
    await mount(`${SEAFOAM}${chip("H1", "seafoam-b4f")}`);

    click("H1");

    expect(jumped().map).toBe("seafoam-b2f");
  });

  it("does nothing when no map on the page draws the letter", async () => {
    await mount(`${SEAFOAM}${chip("T4", "seafoam-b3f")}`);

    click("T4");

    expect(jumps).toEqual([]);
  });

  it("stays inside its own stop on a page that stacks several", async () => {
    await mount(`
      <div class="pn-wt-band-wrap">${block("route-20", [["E1", "exit-1-1", "exit"]])}</div>
      <div class="pn-wt-band-wrap">
        ${block("seafoam-1f", [["E1", "exit-4-17", "exit"]])}
        ${chip("E1", "seafoam-1f")}
      </div>`);

    click("E1");

    expect(jumped().map).toBe("seafoam-1f");
  });

  it("hands the selection to the map's own controller so the pin opens its hint", async () => {
    await mount(`${SEAFOAM}${chip("H1", "seafoam-b3f")}`);
    const maps = stubMaps();

    click("H1");

    expect(maps["seafoam-b3f"].hintValue).toBe("hidden-9-16");
  });

  it("closes the hint it left open on the floor before", async () => {
    await mount(`${SEAFOAM}${chip("H1", "seafoam-b3f")}${chip("E13", "seafoam-b4f")}`);
    const maps = stubMaps();
    click("H1");

    click("E13");

    expect(maps["seafoam-b2f"].hintValue).toBe("exit-13-7");
    expect(maps["seafoam-b3f"].hintValue).toBe("");
  });

  it("still scrolls when the map's controller is not up yet", async () => {
    await mount(`${SEAFOAM}${chip("H1", "seafoam-b3f")}`);
    application.getControllerForElementAndIdentifier = vi.fn().mockReturnValue(null);

    click("H1");

    expect(jumped().map).toBe("seafoam-b3f");
  });
});
