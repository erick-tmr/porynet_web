import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  SCHEMA_VERSION,
  STORAGE_KEY,
  countSet,
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
    expect(load()).toEqual({ v: SCHEMA_VERSION, collected: {}, caught: {} });
  });

  it("reads back what was saved", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, collected: { yellow: { a: true } }, caught: {} }));

    expect(load().collected.yellow).toEqual({ a: true });
  });

  it("discards a payload written by a future schema rather than half-reading it", () => {
    seed(JSON.stringify({ v: 99, collected: { yellow: { a: true } } }));

    expect(load()).toEqual({ v: SCHEMA_VERSION, collected: {}, caught: {} });
  });

  it("survives a corrupted payload", () => {
    seed("{ not json");

    expect(load()).toEqual({ v: SCHEMA_VERSION, collected: {}, caught: {} });
  });

  it("fills in a section the payload is missing", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, collected: { yellow: { a: true } } }));

    expect(load().caught).toEqual({});
  });

  it("ignores a section that is not an object", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, collected: "nope", caught: null }));

    expect(load()).toEqual({ v: SCHEMA_VERSION, collected: {}, caught: {} });
  });

  it("falls back when storage is unreadable, as in private mode", () => {
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("SecurityError");
    });

    expect(load()).toEqual({ v: SCHEMA_VERSION, collected: {}, caught: {} });
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

  it("ignores writes to somebody else's key", () => {
    const seen = [];
    subscribe((state) => seen.push(state));

    window.dispatchEvent(new StorageEvent("storage", { key: "unrelated" }));

    expect(seen).toHaveLength(0);
  });
});
