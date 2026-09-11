import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import SyncBannerController from "../../app/javascript/controllers/sync_banner_controller.js";
import { SCHEMA_VERSION, STORAGE_KEY } from "../../app/javascript/lib/progress_store.js";
import { SYNCED_EVENT } from "../../app/javascript/lib/sync_payload.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
const after = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

let application;

const FIXTURE = `
  <div id="sync" class="pn-sync" hidden
       data-controller="sync-banner"
       data-sync-banner-url-value="/walkthroughs/yellow/sync"
       data-sync-banner-batch-size-value="1"
       data-sync-banner-dismiss-ms-value="60"
       data-sync-banner-tick-ms-value="10"
       data-sync-banner-fade-value="10">
    <span data-sync-banner-target="marks">0</span>
    <span data-sync-banner-target="species">0</span>
    <span data-sync-banner-target="pokemon">0</span>
    <span data-sync-banner-target="sent">0</span>
    <span data-sync-banner-target="total">0</span>
    <span data-sync-banner-target="pct">0</span>
    <span data-sync-banner-target="seconds">0</span>
    <span data-sync-banner-target="attempt">0</span>
    <button id="retry" data-action="sync-banner#retry">retry</button>
    <button id="keep" data-action="sync-banner#dismiss">keep</button>
  </div>
`;

const SLOW = FIXTURE.replace('data-sync-banner-dismiss-ms-value="60"',
  'data-sync-banner-dismiss-ms-value="9000"');

const banner = () => document.getElementById("sync");
const phase = () => [...banner().classList].find((name) => name.startsWith("is-"));
const slot = (role) => banner().querySelector(`[data-sync-banner-target='${role}']`).textContent;

function store(collected = { "route-2/item-a": true, "route-2/item-b": true }) {
  localStorage.setItem(STORAGE_KEY, JSON.stringify({
    v: SCHEMA_VERSION, collected: { yellow: collected }, caught: {}, bodies: { yellow: { "025": 2 } },
  }));
}

function replies(...outcomes) {
  const fetcher = vi.fn(() => {
    const next = outcomes.length > 1 ? outcomes.shift() : outcomes[0];
    return next instanceof Error ? Promise.reject(next) : Promise.resolve({ ok: next });
  });
  globalThis.fetch = fetcher;
  return fetcher;
}

async function mount(html = FIXTURE) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("sync-banner", SyncBannerController);
  await flush();
  await flush();
}

beforeEach(() => {
  localStorage.clear();
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
  delete globalThis.fetch;
});

describe("sync_banner_controller", () => {
  it("stays out of the way when this browser has nothing to send", async () => {
    const fetcher = replies(true);
    await mount();

    expect(banner().hidden).toBe(true);
    expect(fetcher).not.toHaveBeenCalled();
  });

  it("clears the way for write-through even with nothing to adopt", async () => {
    replies(true);
    let synced = false;
    const listener = () => { synced = true; };
    window.addEventListener(SYNCED_EVENT, listener);

    await mount();
    window.removeEventListener(SYNCED_EVENT, listener);

    expect(synced).toBe(true);
  });

  it("clears the way for write-through once the run is in", async () => {
    store();
    replies(true);
    let synced = false;
    const listener = () => { synced = true; };
    window.addEventListener(SYNCED_EVENT, listener);

    await mount();
    await after(20);
    window.removeEventListener(SYNCED_EVENT, listener);

    expect(synced).toBe(true);
  });

  it("counts the payload up front, then uploads it a batch at a time", async () => {
    store();
    const fetcher = replies(true);
    await mount();

    expect(banner().hidden).toBe(false);
    expect(slot("marks")).toBe("2");
    expect(slot("species")).toBe("1");
    expect(slot("pokemon")).toBe("2");
    expect(slot("total")).toBe("3");

    await after(20);

    expect(fetcher).toHaveBeenCalledTimes(3);
    expect(slot("sent")).toBe("3");
    expect(slot("pct")).toBe("100%");
    expect(banner().style.getPropertyValue("--pn-sync-pct")).toBe("100%");
  });

  it("tells the server which batch is the last one", async () => {
    store();
    const fetcher = replies(true);
    await mount();
    await after(20);

    const finals = fetcher.mock.calls.map(([ , init ]) => JSON.parse(init.body).final);

    expect(finals).toEqual([ false, false, true ]);
  });

  it("carries the page's forgery token", async () => {
    document.head.innerHTML = '<meta name="csrf-token" content="abc123">';
    store();
    const fetcher = replies(true);
    await mount();
    await after(20);

    expect(fetcher.mock.calls[0][1].headers["X-CSRF-Token"]).toBe("abc123");
    document.head.innerHTML = "";
  });

  it("sends an empty token rather than nothing when the page carries none", async () => {
    store();
    const fetcher = replies(true);
    await mount();
    await after(20);

    expect(fetcher.mock.calls[0][1].headers["X-CSRF-Token"]).toBe("");
  });

  it("drains the bar once every batch is in, then takes itself out of the layout", async () => {
    store();
    replies(true);
    await mount();
    await after(20);

    expect(phase()).toBe("is-done");
    expect(banner().style.getPropertyValue("--pn-sync-drain")).not.toBe("");
    expect(Number(slot("seconds"))).toBeLessThanOrEqual(1);

    await after(120);

    expect(banner().classList.contains("is-gone")).toBe(true);
    expect(banner().hidden).toBe(true);
  });

  it("clears sooner when the trainer asks", async () => {
    store();
    replies(true);
    await mount(SLOW);
    await after(20);

    document.getElementById("keep").click();
    await after(30);

    expect(banner().hidden).toBe(true);
  });

  it("stops at the batch that did not land and offers a retry", async () => {
    store();
    const fetcher = replies(false);
    await mount();
    await after(20);

    expect(phase()).toBe("is-failed");
    expect(slot("attempt")).toBe("1");
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(slot("sent")).toBe("0");
  });

  it("reads a connection that never answered as a failure too", async () => {
    store();
    replies(new Error("offline"));
    await mount();
    await after(20);

    expect(phase()).toBe("is-failed");
  });

  it("picks up at the batch that broke rather than starting over", async () => {
    store();
    const fetcher = replies(true, false, true);
    await mount();
    await after(20);

    expect(phase()).toBe("is-failed");
    expect(slot("sent")).toBe("1");

    document.getElementById("retry").click();
    await after(20);

    expect(phase()).toBe("is-done");
    expect(fetcher).toHaveBeenCalledTimes(4);
  });

  it("counts the attempts, and never past the number the copy names", async () => {
    store();
    replies(false);
    await mount();
    await after(20);

    expect(slot("attempt")).toBe("1");

    for (let go = 0; go < 3; go += 1) {
      document.getElementById("retry").click();
      await after(20);
    }

    expect(slot("attempt")).toBe("3");
  });

  it("drops an upload that is still in the air when the page is left", async () => {
    store();
    let answer;
    globalThis.fetch = vi.fn(() => new Promise((resolve) => { answer = resolve; }));
    await mount();
    const element = banner();

    element.remove();
    await flush();
    answer({ ok: true });
    await after(20);

    expect([ ...element.classList ]).toContain("is-syncing");
  });
});
