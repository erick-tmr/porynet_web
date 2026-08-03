import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import NavMenuController from "../../app/javascript/controllers/nav_menu_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

const FIXTURE = `
  <header id="nav" class="pn-nav" data-controller="nav-menu"
          data-action="keydown.esc@window->nav-menu#close">
    <button id="burger" type="button" aria-expanded="false" aria-controls="pn-nav-panel"
            data-nav-menu-target="button" data-action="nav-menu#toggle"></button>
    <nav id="pn-nav-panel" class="pn-nav__panel"></nav>
  </header>
`;

async function mount() {
  document.body.innerHTML = FIXTURE;
  application = Application.start();
  application.register("nav-menu", NavMenuController);
  await flush();
}

const isOpen = () => document.getElementById("nav").classList.contains("is-open");
const expanded = () => document.getElementById("burger").getAttribute("aria-expanded");
const escape = () =>
  window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("nav_menu_controller", () => {
  it("starts closed", async () => {
    await mount();

    expect(isOpen()).toBe(false);
    expect(expanded()).toBe("false");
  });

  it("opens and closes on the burger, keeping aria-expanded honest", async () => {
    await mount();

    document.getElementById("burger").click();
    await flush();

    expect(isOpen()).toBe(true);
    expect(expanded()).toBe("true");

    document.getElementById("burger").click();
    await flush();

    expect(isOpen()).toBe(false);
    expect(expanded()).toBe("false");
  });

  it("closes on Escape, and stays closed when Escape comes again", async () => {
    await mount();

    document.getElementById("burger").click();
    await flush();
    escape();
    await flush();

    expect(isOpen()).toBe(false);
    expect(expanded()).toBe("false");

    escape();
    await flush();

    expect(isOpen()).toBe(false);
  });
});
