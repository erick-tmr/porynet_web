import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import DeptStoreController from "../../app/javascript/controllers/dept_store_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

async function mount(html) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("dept-store", DeptStoreController);
  await flush();
}

const store = (startAttr) => `
  <div data-controller="dept-store"${startAttr}>
    <button id="e1" data-dept-store-target="entry" data-floor="1F" data-action="click->dept-store#select"></button>
    <button id="e2" data-dept-store-target="entry" data-floor="2F" data-action="click->dept-store#select"></button>
    <div id="f1" data-dept-store-target="floor" data-floor="1F" hidden></div>
    <div id="f2" data-dept-store-target="floor" data-floor="2F" hidden></div>
  </div>
`;

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("dept_store_controller", () => {
  it("opens the configured start floor and lights its entry", async () => {
    await mount(store(` data-dept-store-start-value="2F"`));

    expect(document.getElementById("f1").hidden).toBe(true);
    expect(document.getElementById("f2").hidden).toBe(false);
    expect(document.getElementById("e2").classList.contains("is-active")).toBe(true);
    expect(document.getElementById("e1").classList.contains("is-active")).toBe(false);
  });

  it("rides to the clicked floor", async () => {
    await mount(store(` data-dept-store-start-value="2F"`));

    document.getElementById("e1").click();
    await flush();

    expect(document.getElementById("f1").hidden).toBe(false);
    expect(document.getElementById("f2").hidden).toBe(true);
    expect(document.getElementById("e1").classList.contains("is-active")).toBe(true);
    expect(document.getElementById("e2").classList.contains("is-active")).toBe(false);
  });

  it("falls back to the first floor when no start is set", async () => {
    await mount(store(""));

    expect(document.getElementById("f1").hidden).toBe(false);
    expect(document.getElementById("f2").hidden).toBe(true);
    expect(document.getElementById("e1").classList.contains("is-active")).toBe(true);
  });

  it("shows nothing when there are no floors to ride", async () => {
    await mount(`<div data-controller="dept-store"></div>`);

    expect(document.querySelector("[data-controller='dept-store']")).not.toBeNull();
  });
});
