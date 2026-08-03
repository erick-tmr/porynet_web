import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  MODES,
  SCHEMA_VERSION,
  STORAGE_KEY,
  isOn,
  load,
  save,
  setMode,
  subscribe,
} from "../../app/javascript/lib/mode_store.js";

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
    expect(load()).toEqual({ v: SCHEMA_VERSION, living: {}, oak: {} });
  });

  it("reads back what was saved", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, living: { yellow: false }, oak: {} }));

    expect(load().living.yellow).toBe(false);
  });

  it("discards a payload written by a future schema rather than half-reading it", () => {
    seed(JSON.stringify({ v: 99, living: { yellow: false } }));

    expect(load()).toEqual({ v: SCHEMA_VERSION, living: {}, oak: {} });
  });

  it("survives a corrupted payload", () => {
    seed("{ not json");

    expect(load()).toEqual({ v: SCHEMA_VERSION, living: {}, oak: {} });
  });

  it("fills in a mode the payload is missing, and ignores one that is not an object", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, oak: "nope" }));

    expect(load()).toEqual({ v: SCHEMA_VERSION, living: {}, oak: {} });
  });

  it("falls back when storage is unreadable, as in private mode", () => {
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("SecurityError");
    });

    expect(load()).toEqual({ v: SCHEMA_VERSION, living: {}, oak: {} });
  });
});

describe("save", () => {
  it("persists and reports success", () => {
    expect(save(setMode(load(), "oak", "yellow", false))).toBe(true);
    expect(stored().oak.yellow).toBe(false);
  });

  it("reports failure when the quota is exhausted instead of throwing at the caller", () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("QuotaExceededError");
    });

    expect(save(load())).toBe(false);
  });
});

describe("isOn", () => {
  it("treats a game nobody has switched as off, for both modes", () => {
    const fresh = load();

    MODES.forEach((mode) => expect(isOn(fresh, mode, "yellow")).toBe(false));
  });

  it("is on only for the mode and game that were switched on", () => {
    const state = setMode(load(), "oak", "yellow", true);

    expect(isOn(state, "oak", "yellow")).toBe(true);
    expect(isOn(state, "oak", "red")).toBe(false);
    expect(isOn(state, "living", "yellow")).toBe(false);
  });
});

describe("setMode", () => {
  it("switches on, back off, and leaves the original state alone", () => {
    const fresh = load();
    const on = setMode(fresh, "living", "yellow", true);
    const off = setMode(on, "living", "yellow", false);

    expect(isOn(on, "living", "yellow")).toBe(true);
    expect(isOn(off, "living", "yellow")).toBe(false);
    expect(fresh.living).toEqual({});
  });

  it("keeps games apart", () => {
    let state = setMode(load(), "oak", "yellow", true);
    state = setMode(state, "oak", "red", false);

    expect(isOn(state, "oak", "yellow")).toBe(true);
    expect(isOn(state, "oak", "red")).toBe(false);
  });
});

describe("subscribe", () => {
  it("reports another tab's write and stops after unsubscribing", () => {
    const seen = [];
    const unsubscribe = subscribe((state) => seen.push(state));

    seed(JSON.stringify({ v: SCHEMA_VERSION, living: {}, oak: { yellow: true } }));
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));

    expect(seen).toHaveLength(1);
    expect(isOn(seen[0], "oak", "yellow")).toBe(true);

    unsubscribe();
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));

    expect(seen).toHaveLength(1);
  });

  it("reports a write from elsewhere on this page, which no storage event would carry", () => {
    const seen = [];
    subscribe((state) => seen.push(state));

    save(setMode(load(), "living", "yellow", true));

    expect(seen).toHaveLength(1);
    expect(isOn(seen[0], "living", "yellow")).toBe(true);
  });

  it("ignores writes to somebody else's key", () => {
    const seen = [];
    subscribe((state) => seen.push(state));

    window.dispatchEvent(new StorageEvent("storage", { key: "unrelated" }));

    expect(seen).toHaveLength(0);
  });
});
