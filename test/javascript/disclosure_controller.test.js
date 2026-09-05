import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import DisclosureController from "../../app/javascript/controllers/disclosure_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

async function mount(html) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("disclosure", DisclosureController);
  await flush();
}

const FIXTURE = `
  <div data-controller="disclosure">
    <button id="toggle" data-disclosure-target="toggle" data-action="disclosure#toggle" aria-expanded="false">Show</button>
    <div id="body" data-disclosure-target="body" hidden>secret</div>
  </div>
`;

const OPEN_FIXTURE = `
  <div data-controller="disclosure" data-disclosure-open-value="true" class="is-open">
    <button id="toggle" data-disclosure-target="toggle" data-action="disclosure#toggle" aria-expanded="true">Hide</button>
    <div id="body" data-disclosure-target="body">secret</div>
  </div>
`;

const ESCAPE_FIXTURE = `
  <div data-controller="disclosure" data-action="keydown.esc@window->disclosure#close">
    <button id="toggle" data-disclosure-target="toggle" data-action="disclosure#toggle" aria-expanded="false">Show</button>
    <div id="body" data-disclosure-target="body" hidden>secret</div>
  </div>
`;

const root = () => document.querySelector("[data-controller='disclosure']");
const escape = () =>
  window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("disclosure_controller", () => {
  it("starts hidden, then opens and closes on toggle", async () => {
    await mount(FIXTURE);

    expect(document.getElementById("body").hidden).toBe(true);
    expect(root().classList.contains("is-open")).toBe(false);
    expect(document.getElementById("toggle").getAttribute("aria-expanded")).toBe("false");

    document.getElementById("toggle").click();
    await flush();

    expect(document.getElementById("body").hidden).toBe(false);
    expect(root().classList.contains("is-open")).toBe(true);
    expect(document.getElementById("toggle").getAttribute("aria-expanded")).toBe("true");

    document.getElementById("toggle").click();
    await flush();

    expect(document.getElementById("body").hidden).toBe(true);
    expect(root().classList.contains("is-open")).toBe(false);
  });

  it("starts open when the markup says so, and still closes on toggle", async () => {
    await mount(OPEN_FIXTURE);

    expect(document.getElementById("body").hidden).toBe(false);
    expect(root().classList.contains("is-open")).toBe(true);
    expect(document.getElementById("toggle").getAttribute("aria-expanded")).toBe("true");

    document.getElementById("toggle").click();
    await flush();

    expect(document.getElementById("body").hidden).toBe(true);
    expect(root().classList.contains("is-open")).toBe(false);
    expect(document.getElementById("toggle").getAttribute("aria-expanded")).toBe("false");
  });

  it("closes on Escape, so the account menu does not have to be clicked shut", async () => {
    await mount(ESCAPE_FIXTURE);

    document.getElementById("toggle").click();
    await flush();

    expect(root().classList.contains("is-open")).toBe(true);

    escape();
    await flush();

    expect(document.getElementById("body").hidden).toBe(true);
    expect(root().classList.contains("is-open")).toBe(false);
    expect(document.getElementById("toggle").getAttribute("aria-expanded")).toBe("false");
  });

  it("stays closed when Escape comes again", async () => {
    await mount(ESCAPE_FIXTURE);

    escape();
    await flush();

    expect(root().classList.contains("is-open")).toBe(false);

    escape();
    await flush();

    expect(root().classList.contains("is-open")).toBe(false);
  });
});
