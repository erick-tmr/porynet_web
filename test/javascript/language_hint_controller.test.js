import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import LanguageHintController from "../../app/javascript/controllers/language_hint_controller.js";

// Stimulus reacts on a later microtask; a delay-0 reveal timeout then fires on
// the next macrotask. flush() drains one such turn.
const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

// jsdom ships no matchMedia — stub it per test to drive the reduced-motion path.
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

    await flush(); // let the delay-0 reveal timeout fire
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

  it("cancels the scheduled reveal when disconnected before it fires", async () => {
    stubMatchMedia(false);
    await mount(`<div id="hint" data-controller="language-hint" data-language-hint-delay-value="100"></div>`);
    const hint = document.getElementById("hint");

    hint.remove(); // -> disconnect() clears the pending timeout
    await flush();

    await new Promise((resolve) => setTimeout(resolve, 130)); // past the 100ms delay
    expect(hint.classList.contains("is-shown")).toBe(false);
  });
});
