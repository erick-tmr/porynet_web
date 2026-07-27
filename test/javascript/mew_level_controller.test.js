import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import MewLevelController from "../../app/javascript/controllers/mew_level_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

async function mount(html) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("mew-level", MewLevelController);
  await flush();
}

// Three stages are enough to exercise every path: -6 (Lv 1), 0 (default), +3 (Lv 10).
const FIXTURE = `
  <div data-controller="mew-level" data-mew-level-baseline-value="7">
    <button id="s-6" data-mew-level-target="button" data-stage="-6" data-action="click->mew-level#pick">-6</button>
    <button id="s0"  class="is-active" data-mew-level-target="button" data-stage="0"  data-action="click->mew-level#pick">0</button>
    <button id="s3"  data-mew-level-target="button" data-stage="3"  data-action="click->mew-level#pick">+3</button>
    <span data-mew-level-target="level">7</span>
    <div id="r-6" data-mew-level-target="recipe" data-stage="-6" hidden></div>
    <div id="r0"  data-mew-level-target="recipe" data-stage="0"></div>
    <div id="r3"  data-mew-level-target="recipe" data-stage="3" hidden></div>
  </div>
`;

const active = (id) => document.getElementById(id).classList.contains("is-active");
const hidden = (id) => document.getElementById(id).hidden;
const level = () => document.querySelector("[data-mew-level-target='level']").textContent;

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("mew_level_controller", () => {
  it("keeps the server-rendered default (stage 0 = Lv 7) on connect", async () => {
    await mount(FIXTURE);

    expect(active("s0")).toBe(true);
    expect(hidden("r0")).toBe(false);
    expect(level()).toBe("7");
  });

  it("picks a stage: updates the level, active button, and visible recipe", async () => {
    await mount(FIXTURE);

    document.getElementById("s-6").click();
    await flush();

    expect(level()).toBe("1");
    expect(active("s-6")).toBe(true);
    expect(active("s0")).toBe(false);
    expect(hidden("r-6")).toBe(false);
    expect(hidden("r0")).toBe(true);

    document.getElementById("s3").click();
    await flush();

    expect(level()).toBe("10");
    expect(active("s3")).toBe(true);
    expect(active("s-6")).toBe(false);
    expect(hidden("r3")).toBe(false);
    expect(hidden("r-6")).toBe(true);
  });
});
