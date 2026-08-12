import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import {
  SCHEMA_VERSION,
  STORAGE_KEY,
  isOpen,
  load,
  save,
  setOpen,
  subscribe,
} from "../../app/javascript/lib/section_store.js";

const EMPTY = { v: SCHEMA_VERSION, folds: {} };

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
    expect(load()).toEqual(EMPTY);
  });

  it("reads back what was saved", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, folds: { yellow: { "route-24/grass": false } } }));

    expect(load().folds.yellow["route-24/grass"]).toBe(false);
  });

  it("discards a payload written by a future schema rather than half-reading it", () => {
    seed(JSON.stringify({ v: 99, folds: { yellow: { "route-24/grass": false } } }));

    expect(load()).toEqual(EMPTY);
  });

  it("survives a corrupted payload", () => {
    seed("{ not json");

    expect(load()).toEqual(EMPTY);
  });

  it("ignores a folds entry that is not an object", () => {
    seed(JSON.stringify({ v: SCHEMA_VERSION, folds: "nope" }));

    expect(load()).toEqual(EMPTY);
  });

  it("falls back when storage is unreadable, as in private mode", () => {
    vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
      throw new Error("SecurityError");
    });

    expect(load()).toEqual(EMPTY);
  });
});

describe("save", () => {
  it("persists and reports success", () => {
    expect(save(setOpen(load(), "yellow", "route-24/grass", false))).toBe(true);
    expect(stored().folds.yellow["route-24/grass"]).toBe(false);
  });

  it("reports failure when the quota is exhausted instead of throwing at the caller", () => {
    vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
      throw new Error("QuotaExceededError");
    });

    expect(save(load())).toBe(false);
  });
});

describe("isOpen", () => {
  it("treats a box nobody has folded as open, whatever the game or stop", () => {
    expect(isOpen(load(), "yellow", "route-24/grass")).toBe(true);
  });

  it("is closed only for the exact game and box that were folded", () => {
    const state = setOpen(load(), "yellow", "route-24/grass", false);

    expect(isOpen(state, "yellow", "route-24/grass")).toBe(false);
    expect(isOpen(state, "yellow", "route-24/super-rod")).toBe(true);
    expect(isOpen(state, "red", "route-24/grass")).toBe(true);
  });
});

describe("setOpen", () => {
  it("folds, unfolds, and leaves the original state alone", () => {
    const fresh = load();
    const closed = setOpen(fresh, "yellow", "route-24/grass", false);
    const reopened = setOpen(closed, "yellow", "route-24/grass", true);

    expect(isOpen(closed, "yellow", "route-24/grass")).toBe(false);
    expect(isOpen(reopened, "yellow", "route-24/grass")).toBe(true);
    expect(fresh.folds).toEqual({});
  });

  it("drops a reopened box rather than storing it, so the payload only tracks folds", () => {
    let state = setOpen(load(), "yellow", "route-24/grass", false);
    state = setOpen(state, "yellow", "route-24/grass", true);

    expect(state.folds.yellow).toEqual({});
  });

  it("keeps games apart", () => {
    let state = setOpen(load(), "yellow", "route-24/grass", false);
    state = setOpen(state, "red", "route-24/grass", true);

    expect(isOpen(state, "yellow", "route-24/grass")).toBe(false);
    expect(isOpen(state, "red", "route-24/grass")).toBe(true);
  });
});

describe("subscribe", () => {
  it("reports another tab's write and stops after unsubscribing", () => {
    const seen = [];
    const unsubscribe = subscribe((state) => seen.push(state));

    seed(JSON.stringify({ v: SCHEMA_VERSION, folds: { yellow: { "route-24/grass": false } } }));
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));

    expect(seen).toHaveLength(1);
    expect(isOpen(seen[0], "yellow", "route-24/grass")).toBe(false);

    unsubscribe();
    window.dispatchEvent(new StorageEvent("storage", { key: STORAGE_KEY }));

    expect(seen).toHaveLength(1);
  });

  it("reports a write from elsewhere on this page, which no storage event would carry", () => {
    const seen = [];
    subscribe((state) => seen.push(state));

    save(setOpen(load(), "yellow", "route-24/grass", false));

    expect(seen).toHaveLength(1);
    expect(isOpen(seen[0], "yellow", "route-24/grass")).toBe(false);
  });

  it("ignores writes to somebody else's key", () => {
    const seen = [];
    subscribe((state) => seen.push(state));

    window.dispatchEvent(new StorageEvent("storage", { key: "unrelated" }));

    expect(seen).toHaveLength(0);
  });
});
