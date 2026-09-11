import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  SCHEMA_VERSION,
  STORAGE_KEY,
  adopt,
  forget,
  onAccount,
  bump,
  countOf,
  countSet,
  diff,
  exportJson,
  importJson,
  isSet,
  load,
  save,
  subscribe,
  toggle,
} from "../../app/javascript/lib/progress_store.js";

const seed = (value) => localStorage.setItem(STORAGE_KEY, value);

const stored = () => JSON.parse(localStorage.getItem(STORAGE_KEY));

beforeEach(() => {
  localStorage.clear();
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("load", () => {
  it("starts empty when nothing has been stored", () => {
    expect(load()).toEqual({ v: SCHEMA_VERSION, collected: {}, caught: {}, bodies: {} });
  });

  it("reads back what was saved", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, collected: { yellow: { a: true } }, caught: {} }));

    expect(load().collected.yellow).toEqual({ a: true });
  });

  it("takes up a run ticked before the ids were named", () => {
    seed(JSON.stringify({
      v: 1,
      collected: { yellow: { "route-2/item-13-54": true } },
      caught: { yellow: { "025": true } },
      bodies: { yellow: { "025": 2 } },
    }));

    expect(load()).toEqual({
      v: SCHEMA_VERSION,
      collected: { yellow: { "route-2/item-13-54": true } },
      caught: { yellow: { "025": true } },
      bodies: { yellow: { "025": 2 } },
    });
  });

  it("folds the rooftop swaps a v1 run filed under their own kind back into collected", () => {
    seed(JSON.stringify({
      v: 1,
      collected: { yellow: { "route-2/item-13-54": true } },
      traded: { yellow: { "celadon-city/roof-trade-tm18": true }, red: { "a/b": true } },
    }));

    expect(load().collected).toEqual({
      yellow: { "route-2/item-13-54": true, "celadon-city/roof-trade-tm18": true },
      red: { "a/b": true },
    });
  });

  it("reads a v1 run that never ticked anything", () => {
    seed(JSON.stringify({ v: 1 }));

    expect(load()).toEqual({ v: SCHEMA_VERSION, collected: {}, caught: {}, bodies: {} });
  });

  it("discards a payload written by a future schema rather than half-reading it", () => {
    seed(JSON.stringify({ v: 99, collected: { yellow: { a: true } } }));

    expect(load()).toEqual({ v: SCHEMA_VERSION, collected: {}, caught: {}, bodies: {} });
  });

  it("survives a corrupted payload", () => {
    seed("{ not json");

    expect(load()).toEqual({ v: SCHEMA_VERSION, collected: {}, caught: {}, bodies: {} });
  });

  it("fills in a section the payload is missing", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, collected: { yellow: { a: true } } }));

    expect(load().caught).toEqual({});
  });

  it("ignores a section that is not an object", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, collected: "nope", caught: null }));

    expect(load()).toEqual({ v: SCHEMA_VERSION, collected: {}, caught: {}, bodies: {} });
  });

  it("falls back when storage is unreadable, as in private mode", () => {
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("SecurityError");
    });

    expect(load()).toEqual({ v: SCHEMA_VERSION, collected: {}, caught: {}, bodies: {} });
  });
});

describe("save", () => {
  it("persists and reports success", () => {
    expect(save({ v: SCHEMA_VERSION, collected: { yellow: { a: true } }, caught: {} })).toBe(true);
    expect(stored().collected.yellow.a).toBe(true);
  });

  it("reports failure when the quota is exhausted instead of throwing at the caller", () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("QuotaExceededError");
    });

    expect(save(load())).toBe(false);
  });
});

describe("isSet", () => {
  it("is false for an unknown kind, game or id", () => {
    const state = toggle(load(), "collected", "yellow", "trainer-1-2");

    expect(isSet(state, "collected", "yellow", "trainer-1-2")).toBe(true);
    expect(isSet(state, "collected", "yellow", "other")).toBe(false);
    expect(isSet(state, "collected", "red", "trainer-1-2")).toBe(false);
    expect(isSet(state, "caught", "yellow", "trainer-1-2")).toBe(false);
  });
});

describe("toggle", () => {
  it("ticks, unticks, and leaves the original state alone", () => {
    const empty = load();
    const on = toggle(empty, "collected", "yellow", "item-1-2");
    const off = toggle(on, "collected", "yellow", "item-1-2");

    expect(isSet(on, "collected", "yellow", "item-1-2")).toBe(true);
    expect(isSet(off, "collected", "yellow", "item-1-2")).toBe(false);
    expect(isSet(empty, "collected", "yellow", "item-1-2")).toBe(false);
  });

  it("keeps games apart", () => {
    let state = toggle(load(), "caught", "yellow", "010");
    state = toggle(state, "caught", "red", "010");

    expect(isSet(state, "caught", "yellow", "010")).toBe(true);
    expect(isSet(state, "caught", "red", "010")).toBe(true);
  });
});

describe("countSet", () => {
  it("counts only the ids that are ticked", () => {
    let state = toggle(load(), "collected", "yellow", "a");
    state = toggle(state, "collected", "yellow", "c");

    expect(countSet(state, "collected", "yellow", ["a", "b", "c"])).toBe(2);
    expect(countSet(state, "collected", "yellow", [])).toBe(0);
  });
});

describe("export and import", () => {
  it("round-trips a state", () => {
    const state = toggle(load(), "collected", "yellow", "hidden-1-2");

    expect(importJson(exportJson(state))).toEqual(state);
  });

  it("rejects junk, a foreign schema, and an empty payload", () => {
    expect(importJson("not json")).toBeNull();
    expect(importJson(JSON.stringify({ v: 99 }))).toBeNull();
    expect(importJson(JSON.stringify(null))).toBeNull();
  });
});

describe("subscribe", () => {
  it("reports another tab's write and stops after unsubscribing", () => {
    const seen = [];
    const unsubscribe = subscribe((state) => seen.push(state));

    seed(JSON.stringify({ v: SCHEMA_VERSION, collected: { yellow: { a: true } }, caught: {} }));
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));

    expect(seen).toHaveLength(1);
    expect(seen[0].collected.yellow.a).toBe(true);

    unsubscribe();
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));

    expect(seen).toHaveLength(1);
  });

  it("reports a write from elsewhere on this page, which no storage event would carry", () => {
    const seen = [];
    subscribe((state) => seen.push(state));

    save(toggle(load(), "collected", "yellow", "route-11/trainer-10-14"));

    expect(seen).toHaveLength(1);
    expect(seen[0].collected.yellow["route-11/trainer-10-14"]).toBe(true);
  });

  it("ignores writes to somebody else's key", () => {
    const seen = [];
    subscribe((state) => seen.push(state));

    window.dispatchEvent(new StorageEvent("storage", { key: "unrelated" }));

    expect(seen).toHaveLength(0);
  });
});

describe("counting bodies", () => {
  it("reads zero for a species nobody has caught", () => {
    expect(countOf(load(), "yellow", "010")).toBe(0);
  });

  it("counts past the quota, so spare bodies can be banked", () => {
    let state = bump(load(), "yellow", "010", 1);
    expect(countOf(state, "yellow", "010")).toBe(1);

    state = bump(state, "yellow", "010", 1);
    state = bump(state, "yellow", "010", 1);

    expect(countOf(state, "yellow", "010")).toBe(3);
  });

  it("never counts below zero", () => {
    const state = bump(load(), "yellow", "010", -1);

    expect(countOf(state, "yellow", "010")).toBe(0);
  });

  it("registers the species as caught while it holds a body, and drops it when empty", () => {
    let state = bump(load(), "yellow", "010", 1);
    expect(isSet(state, "caught", "yellow", "010")).toBe(true);

    state = bump(state, "yellow", "010", -1);

    expect(isSet(state, "caught", "yellow", "010")).toBe(false);
  });

  it("leaves the other games and kinds alone", () => {
    const before = toggle(load(), "collected", "yellow", "route-1/step-1/item-0");
    const state = bump(before, "yellow", "010", 1);

    expect(isSet(state, "collected", "yellow", "route-1/step-1/item-0")).toBe(true);
    expect(countOf(state, "red", "010")).toBe(0);
  });

  it("reads a species registered before bodies existed as holding one", () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({ v: SCHEMA_VERSION, collected: {}, caught: { yellow: { "010": true } } }),
    );

    const state = load();

    expect(isSet(state, "caught", "yellow", "010")).toBe(true);
    expect(countOf(state, "yellow", "010")).toBe(1);
  });

  it("leaves a body count that was already written alone", () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({
        v: SCHEMA_VERSION,
        collected: {},
        caught: { yellow: { "016": true } },
        bodies: { yellow: { "016": 3 } },
      }),
    );

    expect(countOf(load(), "yellow", "016")).toBe(3);
  });
});

describe("one species, two views", () => {
  it("gives a species its first body when a card is ticked caught", () => {
    const state = toggle(load(), "caught", "yellow", "025");

    expect(isSet(state, "caught", "yellow", "025")).toBe(true);
    expect(countOf(state, "yellow", "025")).toBe(1);
  });

  it("keeps a bigger count when the card is ticked off and on again", () => {
    let state = bump(load(), "yellow", "016", 1);
    state = bump(state, "yellow", "016", 1);
    expect(countOf(state, "yellow", "016")).toBe(2);

    state = toggle(state, "caught", "yellow", "016");
    expect(countOf(state, "yellow", "016")).toBe(0);

    state = toggle(state, "caught", "yellow", "016");
    expect(countOf(state, "yellow", "016")).toBe(1);
  });

  it("clears every body when a card is un-ticked", () => {
    let state = bump(load(), "yellow", "010", 1);
    state = toggle(state, "caught", "yellow", "010");

    expect(isSet(state, "caught", "yellow", "010")).toBe(false);
    expect(countOf(state, "yellow", "010")).toBe(0);
  });

  it("leaves a collected marker alone, since only species have bodies", () => {
    const state = toggle(load(), "collected", "yellow", "route-1/step-1/item-0");

    expect(isSet(state, "collected", "yellow", "route-1/step-1/item-0")).toBe(true);
    expect(state.bodies.yellow).toBeUndefined();
  });
});

describe("diff", () => {
  const state = (collected = {}, bodies = {}) => ({ collected, caught: {}, bodies });

  it("reports a tick as the id going on", () => {
    expect(diff(state({ yellow: {} }), state({ yellow: { "route-1/item-a": true } })))
      .toEqual({ yellow: { marks: { "route-1/item-a": true }, bodies: {} } });
  });

  it("reports an untick as the id going off, which a bare snapshot could not say", () => {
    expect(diff(state({ yellow: { "route-1/item-a": true } }), state({ yellow: {} })))
      .toEqual({ yellow: { marks: { "route-1/item-a": false }, bodies: {} } });
  });

  it("reports a body count as the number it should be held at", () => {
    expect(diff(state({}, { yellow: { "025": 1 } }), state({}, { yellow: { "025": 3 } })))
      .toEqual({ yellow: { marks: {}, bodies: { "025": 3 } } });
  });

  it("reports a released species as zero rather than dropping it", () => {
    expect(diff(state({}, { yellow: { "025": 2 } }), state({}, { yellow: {} })))
      .toEqual({ yellow: { marks: {}, bodies: { "025": 0 } } });
  });

  it("reads a document that is missing a kind rather than throwing on it", () => {
    expect(diff({}, { collected: { yellow: { a: true } } }))
      .toEqual({ yellow: { marks: { a: true }, bodies: {} } });
  });

  it("says nothing about a game that did not move", () => {
    const held = state({ yellow: { a: true } }, { red: { "001": 1 } });

    expect(diff(held, held)).toEqual({});
  });

  it("keeps one game's ticks out of another's", () => {
    const changed = diff(state({ yellow: { a: true } }), state({ yellow: { a: true }, red: { b: true } }));

    expect(changed).toEqual({ red: { marks: { b: true }, bodies: {} } });
  });
});

describe("save", () => {
  it("carries what changed on the event, so a listener need not diff again", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, collected: { yellow: { a: true } }, caught: {} }));
    let detail;
    const listener = (event) => { detail = event.detail; };
    window.addEventListener("porynet:progress", listener);

    save({ v: SCHEMA_VERSION, collected: { yellow: { a: true, b: true } }, caught: {}, bodies: {} });
    window.removeEventListener("porynet:progress", listener);

    expect(detail.changed).toEqual({ yellow: { marks: { b: true }, bodies: {} } });
  });
});

describe("the account backend", () => {
  const page = (state, adopted = "true") => {
    document.body.innerHTML = `<div class="porynet"
      data-progress-adopted="${adopted}"
      data-progress-state='${JSON.stringify(state)}'></div>`;
  };

  const HELD = { collected: { yellow: { "route-2/item-a": true } }, caught: {},
    bodies: { yellow: { "025": 2 } } };

  beforeEach(() => {
    page({}, "false");
    onAccount();
  });

  it("renders a synced trainer from the save file the page carries", () => {
    page(HELD);

    expect(onAccount()).toBe(true);
    expect(load().collected.yellow).toEqual({ "route-2/item-a": true });
    expect(load().bodies.yellow).toEqual({ "025": 2 });
  });

  it("ignores the browser's copy entirely once the save file is in charge", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, collected: { yellow: { stale: true } }, caught: {} }));
    page(HELD);

    expect(load().collected.yellow).toEqual({ "route-2/item-a": true });
  });

  it("stops marking the browser, writing the tick to the account instead", () => {
    page(HELD);
    const next = toggle(load(), "collected", "yellow", "route-2/item-b");

    expect(save(next)).toBe(true);
    expect(load().collected.yellow["route-2/item-b"]).toBe(true);
    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
  });

  it("still reports what changed, so the tick reaches the server", () => {
    page(HELD);
    let detail;
    const listener = (event) => { detail = event.detail; };
    window.addEventListener("porynet:progress", listener);

    save(toggle(load(), "collected", "yellow", "route-2/item-b"));
    window.removeEventListener("porynet:progress", listener);

    expect(detail.changed).toEqual({ yellow: { marks: { "route-2/item-b": true }, bodies: {} } });
  });

  it("leaves a guest on their own browser", () => {
    page(HELD, "false");
    seed(JSON.stringify({ v: SCHEMA_VERSION, collected: { yellow: { mine: true } }, caught: {} }));

    expect(onAccount()).toBe(false);
    expect(load().collected.yellow).toEqual({ mine: true });
  });

  it("falls back to the browser when the page carries a state it cannot read", () => {
    document.body.innerHTML = `<div data-progress-adopted="true" data-progress-state="{nope"></div>`;

    expect(onAccount()).toBe(false);
  });

  it("hands over at the moment the run lands, and drops the browser's copy", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, collected: { yellow: { mine: true } }, caught: {} }));

    expect(onAccount()).toBe(false);

    adopt(load());
    forget();

    expect(onAccount()).toBe(true);
    expect(load().collected.yellow).toEqual({ mine: true });
    expect(localStorage.getItem(STORAGE_KEY)).toBeNull();
  });

  it("says so rather than throwing when the browser refuses to drop its copy", () => {
    vi.spyOn(Storage.prototype, "removeItem").mockImplementation(() => { throw new Error("nope"); });

    expect(forget()).toBe(false);
  });
});
