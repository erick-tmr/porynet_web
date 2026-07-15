import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import OakToggleController from "../../app/javascript/controllers/oak_toggle_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

async function mount(html) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("oak-toggle", OakToggleController);
  await flush();
}

const isActive = (id) => document.getElementById(id).classList.contains("is-active");

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("oak_toggle_controller", () => {
  it("activates the default mode on connect and flips button + stat card on select", async () => {
    await mount(`
      <div data-controller="oak-toggle" data-oak-toggle-mode-value="oak">
        <button id="btn-oak"    data-oak-toggle-target="button"   data-oak-mode="oak"    data-action="click->oak-toggle#select"></button>
        <button id="btn-living" data-oak-toggle-target="button"   data-oak-mode="living" data-action="click->oak-toggle#select"></button>
        <div    id="card-oak"    data-oak-toggle-target="statCard" data-oak-mode="oak"></div>
        <div    id="card-living" data-oak-toggle-target="statCard" data-oak-mode="living"></div>
      </div>
    `);

    expect(isActive("btn-oak")).toBe(true);
    expect(isActive("card-oak")).toBe(true);
    expect(isActive("btn-living")).toBe(false);
    expect(isActive("card-living")).toBe(false);

    document.getElementById("btn-living").click();
    await flush();

    expect(isActive("btn-living")).toBe(true);
    expect(isActive("card-living")).toBe(true);
    expect(isActive("btn-oak")).toBe(false);
    expect(isActive("card-oak")).toBe(false);
  });
});
