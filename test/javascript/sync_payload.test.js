import { describe, expect, it } from "vitest";
import { KEYS_PER_BATCH, batches, tally } from "../../app/javascript/lib/sync_payload.js";

const STATE = {
  collected: { yellow: { "route-2/item-a": true, "route-2/item-b": true, "route-3/item-c": true } },
  bodies: { yellow: { "025": 2, "016": 1, "010": 0 }, red: { "001": 1 } },
};

describe("sync_payload", () => {
  it("counts the marks, the species and the bodies of one game", () => {
    expect(tally(STATE, "yellow")).toEqual({ marks: 3, species: 2, pokemon: 3, records: 5 });
  });

  it("counts nothing for a game the browser has never played", () => {
    expect(tally(STATE, "blue")).toEqual({ marks: 0, species: 0, pokemon: 0, records: 0 });
  });

  it("counts nothing when the store has no kinds at all", () => {
    expect(tally({}, "yellow")).toEqual({ marks: 0, species: 0, pokemon: 0, records: 0 });
  });

  it("slices a guest document, marks first and then the counts", () => {
    expect(batches(STATE, "yellow", 2)).toEqual([
      { collected: { yellow: { "route-2/item-a": true, "route-2/item-b": true } },
        bodies: {}, records: 2 },
      { collected: { yellow: { "route-3/item-c": true } }, bodies: {}, records: 1 },
      { collected: {}, bodies: { yellow: { "025": 2, "016": 1 } }, records: 2 },
    ]);
  });

  it("keeps a whole run in one batch when it fits", () => {
    const [marks, bodies] = batches(STATE, "yellow");

    expect(marks.records).toBe(3);
    expect(bodies.records).toBe(2);
    expect(KEYS_PER_BATCH).toBe(64);
  });

  it("splits a run larger than one write may hold", () => {
    const many = {};
    for (let n = 0; n < KEYS_PER_BATCH + 1; n += 1) many[`route-1/item-${n}`] = true;

    const sent = batches({ collected: { yellow: many } }, "yellow");

    expect(sent.map((batch) => batch.records)).toEqual([KEYS_PER_BATCH, 1]);
  });

  it("has nothing to send for a game the browser has never played", () => {
    expect(batches(STATE, "blue")).toEqual([]);
  });
});
