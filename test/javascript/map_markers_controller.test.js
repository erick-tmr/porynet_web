import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import MapMarkersController from "../../app/javascript/controllers/map_markers_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

async function mount(html) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("map-markers", MapMarkersController);
  await flush();
}

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("map_markers_controller", () => {
  it("positions each marker from its data-x / data-y percentages and clamps out-of-range values", async () => {
    await mount(`
      <div data-controller="map-markers">
        <span id="m1" data-map-markers-target="marker" data-x="0.25" data-y="0.5"></span>
        <span id="m2" data-map-markers-target="marker" data-x="1.5" data-y="-0.2"></span>
      </div>
    `);

    const m1 = document.getElementById("m1");
    expect(m1.style.left).toBe("25%");
    expect(m1.style.top).toBe("50%");

    const m2 = document.getElementById("m2");
    expect(m2.style.left).toBe("100%");
    expect(m2.style.top).toBe("0%");
  });
});
