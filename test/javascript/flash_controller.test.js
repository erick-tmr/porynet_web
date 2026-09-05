import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import FlashController from "../../app/javascript/controllers/flash_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));
const after = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

let application;

const FIXTURE = `
  <div class="pn-flash">
    <div id="msg" class="pn-flash__msg" role="status"
         data-controller="flash" data-action="click->flash#dismiss"
         data-flash-delay-value="30" data-flash-fade-value="10">Saved</div>
  </div>
`;

const SLOW_FIXTURE = FIXTURE.replace('data-flash-delay-value="30"', 'data-flash-delay-value="9000"');

async function mount(html) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("flash", FlashController);
  await flush();
}

const msg = () => document.getElementById("msg");

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("flash_controller", () => {
  it("clears itself once the delay is up", async () => {
    await mount(FIXTURE);

    expect(msg().classList.contains("is-gone")).toBe(false);
    expect(msg().hidden).toBe(false);

    await after(50);

    expect(msg().classList.contains("is-gone")).toBe(true);
    expect(msg().hidden).toBe(true);
  });

  it("closes on a click, without waiting out the delay", async () => {
    await mount(SLOW_FIXTURE);

    msg().click();
    await flush();

    expect(msg().classList.contains("is-gone")).toBe(true);

    await after(30);

    expect(msg().hidden).toBe(true);
  });

  it("ignores a second dismiss so the fade does not restart", async () => {
    await mount(SLOW_FIXTURE);

    msg().click();
    await flush();
    msg().click();
    await after(30);

    expect(msg().hidden).toBe(true);
  });

  it("drops its timers when the element goes away", async () => {
    await mount(SLOW_FIXTURE);

    const element = msg();
    element.remove();
    await flush();

    expect(element.classList.contains("is-gone")).toBe(false);
  });
});
