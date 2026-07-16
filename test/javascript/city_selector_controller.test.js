import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import CitySelectorController from "../../app/javascript/controllers/city_selector_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

const CITIES = [
  { name: "PALLET TOWN", total: 1, oak: 1, dex: 1, new_mons: [ "Starter" ] },
  { name: "ROUTE 1", total: 3, oak: 3, dex: 5, new_mons: [ "Pidgey", "Rattata" ] },
];

let application;

async function mount(html) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("city-selector", CitySelectorController);
  await flush();
}

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("city_selector_controller", () => {
  it("renders the selected city into every target and re-renders on select", async () => {
    await mount(`
      <div data-controller="city-selector"
           data-city-selector-index-value="0"
           data-city-selector-cities-value='${JSON.stringify(CITIES)}'>
        <button id="c0" data-city-selector-target="button" data-city-index="0" data-action="click->city-selector#select"></button>
        <button id="c1" data-city-selector-target="button" data-city-index="1" data-action="click->city-selector#select"></button>
        <span data-city-selector-target="name"></span>
        <span data-city-selector-target="total"></span>
        <span data-city-selector-target="oak"></span>
        <span data-city-selector-target="dex"></span>
        <div data-city-selector-target="newMons"></div>
      </div>
    `);

    const name = document.querySelector("[data-city-selector-target='name']");
    const total = document.querySelector("[data-city-selector-target='total']");
    const newMons = document.querySelector("[data-city-selector-target='newMons']");

    expect(name.textContent).toBe("PALLET TOWN");
    expect(total.textContent).toBe("1");
    expect(document.getElementById("c0").classList.contains("is-active")).toBe(true);
    expect(document.getElementById("c1").classList.contains("is-active")).toBe(false);
    expect(newMons.children).toHaveLength(1);

    document.getElementById("c1").click();
    await flush();

    expect(name.textContent).toBe("ROUTE 1");
    expect(total.textContent).toBe("3");
    expect(document.getElementById("c1").classList.contains("is-active")).toBe(true);
    expect(document.getElementById("c0").classList.contains("is-active")).toBe(false);

    expect(newMons.children).toHaveLength(2);
    const pill = newMons.children[0];
    expect(pill.className).toBe("pn-mon");
    expect(pill.firstElementChild.className).toBe("pn-mon__dot");
    expect(pill.textContent).toBe("Pidgey");
  });

  it("skips absent optional targets without erroring", async () => {
    await mount(`
      <div data-controller="city-selector"
           data-city-selector-index-value="0"
           data-city-selector-cities-value='${JSON.stringify(CITIES)}'>
        <button id="only" data-city-selector-target="button" data-city-index="0"></button>
      </div>
    `);

    expect(document.getElementById("only").classList.contains("is-active")).toBe(true);
  });

  it("bails out when the index points past the city list", async () => {
    await mount(`
      <div data-controller="city-selector"
           data-city-selector-index-value="5"
           data-city-selector-cities-value='${JSON.stringify(CITIES)}'>
        <span data-city-selector-target="name">untouched</span>
      </div>
    `);

    const name = document.querySelector("[data-city-selector-target='name']");
    expect(name.textContent).toBe("untouched");
  });
});
