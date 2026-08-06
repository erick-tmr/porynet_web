import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import LdStatsController from "../../app/javascript/controllers/ld_stats_controller.js";
import { CHANGE_EVENT, STORAGE_KEY, SCHEMA_VERSION } from "../../app/javascript/lib/progress_store.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

const ENTRIES = [
  { dex: "016", covers: ["016", "017", "018"] },
  { dex: "010", covers: [] },
];

const FIXTURE = `
  <div id="bar" data-controller="ld-stats" data-ld-stats-game-value="yellow"
       data-ld-stats-entries-value='${JSON.stringify(ENTRIES)}'>
    <span data-ld-stats-target="bodies">4</span>
  </div>
`;

async function mount(html = FIXTURE) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("ld-stats", LdStatsController);
  await flush();
}

const bar = () => document.getElementById("bar");
const bodies = () => bar().querySelector("[data-ld-stats-target='bodies']").textContent;
const isClear = () => bar().classList.contains("is-clear");

function store(state) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({ v: SCHEMA_VERSION, collected: {}, ...state }));
  window.dispatchEvent(new CustomEvent(CHANGE_EVENT));
}

beforeEach(() => {
  localStorage.clear();
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("ld_stats_controller", () => {
  it("sums what the queue still owes across its entries", async () => {
    await mount();

    expect(bodies()).toBe("4");
    expect(isClear()).toBe(false);
  });

  it("counts down as specimens are boxed", async () => {
    await mount();
    store({ caught: { yellow: { "016": true } }, bodies: { yellow: { "016": 2 } } });
    await flush();

    expect(bodies()).toBe("2");
  });

  it("drops a species out of the total once its quota is met", async () => {
    await mount();
    store({ caught: { yellow: { "010": true } }, bodies: { yellow: { "010": 1 } } });
    await flush();

    expect(bodies()).toBe("3");
  });

  it("lowers what a stop owes when a spare stage is caught elsewhere", async () => {
    await mount();
    store({ caught: { yellow: { "018": true } }, bodies: { yellow: { "018": 1 } } });
    await flush();

    expect(bodies()).toBe("3");
  });

  it("flips to the cleared state when nothing is left to catch", async () => {
    await mount();
    store({
      caught: { yellow: { "016": true, "010": true } },
      bodies: { yellow: { "016": 3, "010": 1 } },
    });
    await flush();

    expect(bodies()).toBe("0");
    expect(isClear()).toBe(true);
  });

  it("never reports a negative count when the box overflows the quota", async () => {
    await mount();
    store({ caught: { yellow: { "010": true } }, bodies: { yellow: { "010": 9 } } });
    await flush();

    expect(bodies()).toBe("3");
  });

  it("stops listening once disconnected", async () => {
    await mount();
    const el = bar();

    el.remove();
    await flush();
    store({ caught: { yellow: { "010": true } }, bodies: { yellow: { "010": 1 } } });
    await flush();

    expect(el.querySelector("[data-ld-stats-target='bodies']").textContent).toBe("4");
  });
});
