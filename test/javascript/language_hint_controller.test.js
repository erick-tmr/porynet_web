import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import LanguageHintController from "../../app/javascript/controllers/language_hint_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

function stubMatchMedia(matches) {
  window.matchMedia = () => ({ matches });
}

async function mount(html) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("language-hint", LanguageHintController);
  await flush();
}

const HINT = `<div id="hint" data-controller="language-hint" data-language-hint-delay-value="0"></div>`;

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
  delete window.matchMedia;
});

describe("language_hint_controller", () => {
  it("reveals itself after the delay, then hides when the animation ends", async () => {
    stubMatchMedia(false);
    await mount(HINT);
    const hint = document.getElementById("hint");

    await flush();
    expect(hint.classList.contains("is-shown")).toBe(true);

    hint.dispatchEvent(new Event("animationend"));
    expect(hint.classList.contains("is-shown")).toBe(false);
  });

  it("stays hidden when the visitor prefers reduced motion", async () => {
    stubMatchMedia(true);
    await mount(HINT);
    const hint = document.getElementById("hint");

    await flush();
    expect(hint.classList.contains("is-shown")).toBe(false);
  });

  it("no-ops when the bubble target is absent", async () => {
    stubMatchMedia(false);
    await mount(`<div data-controller="language-hint" data-language-hint-delay-value="0"></div>`);
    await flush();

    const controller = application.getControllerForElementAndIdentifier(
      document.querySelector("[data-controller='language-hint']"),
      "language-hint"
    );
    expect(() => controller.hide()).not.toThrow();
  });

  it("cancels the scheduled reveal when disconnected before it fires", async () => {
    stubMatchMedia(false);
    await mount(`
      <div id="hint" data-controller="language-hint" data-language-hint-delay-value="100"></div>
    `);
    const hint = document.getElementById("hint");

    document.querySelector("[data-controller='language-hint']").remove();
    await flush();

    await new Promise((resolve) => setTimeout(resolve, 130));
    expect(hint.classList.contains("is-shown")).toBe(false);
  });
});
