import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import ProgressSyncController from "../../app/javascript/controllers/progress_sync_controller.js";
import { CHANGE_EVENT } from "../../app/javascript/lib/progress_store.js";
import { SYNCED_EVENT } from "../../app/javascript/lib/sync_payload.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
const after = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

let application;

const FIXTURE = `
  <div id="page" data-controller="progress-sync"
       data-progress-sync-url-value="/walkthroughs/yellow/progress"
       data-progress-sync-game-value="yellow"
       data-progress-sync-ready-value="true"
       data-progress-sync-retry-ms-value="20"></div>
`;

const PENDING = FIXTURE.replace('data-progress-sync-ready-value="true"',
  'data-progress-sync-ready-value="false"');
const GUEST = FIXTURE.replace('data-progress-sync-url-value="/walkthroughs/yellow/progress"', "");

const page = () => document.getElementById("page");

function tick(changed) {
  window.dispatchEvent(new CustomEvent(CHANGE_EVENT, { detail: { changed } }));
}

const MARK = { yellow: { marks: { "route-1/item-a": true }, bodies: {} } };

function replies(...outcomes) {
  const fetcher = vi.fn(() => {
    const next = outcomes.length > 1 ? outcomes.shift() : outcomes[0];
    return next instanceof Error ? Promise.reject(next) : Promise.resolve({ ok: next });
  });
  globalThis.fetch = fetcher;
  return fetcher;
}

const sent = (fetcher, at = 0) => JSON.parse(fetcher.mock.calls[at][1].body);

async function mount(html = FIXTURE) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("progress-sync", ProgressSyncController);
  await flush();
}

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(async () => {
  document.body.innerHTML = "";
  await flush();
  application?.stop();
  delete globalThis.fetch;
});

describe("progress_sync_controller", () => {
  it("writes a tick through the moment it is made", async () => {
    const fetcher = replies(true);
    await mount();

    tick(MARK);
    await flush();

    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(fetcher.mock.calls[0][1].method).toBe("PATCH");
    expect(sent(fetcher)).toEqual({ marks: { "route-1/item-a": true }, bodies: {} });
  });

  it("writes an untick through as the id going off", async () => {
    const fetcher = replies(true);
    await mount();

    tick({ yellow: { marks: { "route-1/item-a": false }, bodies: {} } });
    await flush();

    expect(sent(fetcher)).toEqual({ marks: { "route-1/item-a": false }, bodies: {} });
  });

  it("ignores a change to a game this page is not showing", async () => {
    const fetcher = replies(true);
    await mount();

    tick({ red: { marks: { "route-1/item-a": true }, bodies: {} } });
    await flush();

    expect(fetcher).not.toHaveBeenCalled();
  });

  it("stays quiet for a guest, who has nowhere to write to", async () => {
    const fetcher = replies(true);
    await mount(GUEST);

    tick(MARK);
    await flush();

    expect(fetcher).not.toHaveBeenCalled();
  });

  it("holds every tick until the first sync has finished, then sends them as one", async () => {
    const fetcher = replies(true);
    await mount(PENDING);

    tick(MARK);
    tick({ yellow: { marks: { "route-1/item-b": true }, bodies: { "025": 2 } } });
    await flush();

    expect(fetcher).not.toHaveBeenCalled();

    window.dispatchEvent(new CustomEvent(SYNCED_EVENT));
    await flush();

    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(sent(fetcher)).toEqual({
      marks: { "route-1/item-a": true, "route-1/item-b": true }, bodies: { "025": 2 },
    });
  });

  it("lets the last word on an id win when ticks pile up", async () => {
    let answer;
    globalThis.fetch = vi.fn(() => new Promise((resolve) => { answer = resolve; }));
    await mount();

    tick(MARK);
    await flush();
    tick({ yellow: { marks: { "route-1/item-a": false }, bodies: {} } });
    answer({ ok: true });
    await flush();

    expect(sent(globalThis.fetch, 1)).toEqual({ marks: { "route-1/item-a": false }, bodies: {} });
  });

  it("keeps a tick that did not land and tries it again", async () => {
    const fetcher = replies(false, true);
    await mount();

    tick(MARK);
    await flush();

    expect(fetcher).toHaveBeenCalledTimes(1);

    await after(60);

    expect(fetcher).toHaveBeenCalledTimes(2);
    expect(sent(fetcher, 1)).toEqual({ marks: { "route-1/item-a": true }, bodies: {} });
  });

  it("reads a connection that never answered as a write that did not land", async () => {
    const fetcher = replies(new Error("offline"), true);
    await mount();

    tick(MARK);
    await after(60);

    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it("carries the page's forgery token", async () => {
    document.head.innerHTML = '<meta name="csrf-token" content="abc123">';
    const fetcher = replies(true);
    await mount();

    tick(MARK);
    await flush();

    expect(fetcher.mock.calls[0][1].headers["X-CSRF-Token"]).toBe("abc123");
    document.head.innerHTML = "";
  });

  it("drops a write that is still in the air when the page is left", async () => {
    let answer;
    globalThis.fetch = vi.fn(() => new Promise((resolve) => { answer = resolve; }));
    await mount();

    tick(MARK);
    await flush();
    page().remove();
    await flush();
    answer({ ok: true });
    await after(40);

    expect(globalThis.fetch).toHaveBeenCalledTimes(1);
  });

  it("stops listening once it is gone", async () => {
    const fetcher = replies(true);
    await mount();

    page().remove();
    await flush();
    tick(MARK);
    await flush();

    expect(fetcher).not.toHaveBeenCalled();
  });
});
