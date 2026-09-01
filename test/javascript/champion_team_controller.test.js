import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import ChampionTeamController from "../../app/javascript/controllers/champion_team_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

async function mount(html) {
  document.body.innerHTML = html;
  application = Application.start();
  application.register("champion-team", ChampionTeamController);
  await flush();
}

const throne = `
  <div id="card">
    <div data-controller="champion-team">
      <button id="t-jolteon" data-champion-team-target="tab" data-team="jolteon"
              class="is-active" aria-pressed="true" data-action="champion-team#pick"></button>
      <button id="t-flareon" data-champion-team-target="tab" data-team="flareon"
              aria-pressed="false" data-action="champion-team#pick"></button>
      <div id="p-jolteon" data-champion-team-target="panel" data-team="jolteon"></div>
      <div id="p-flareon" data-champion-team-target="panel" data-team="flareon" hidden></div>
    </div>
  </div>
`;

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("champion_team_controller", () => {
  it("swaps to the picked team and marks its tab", async () => {
    await mount(throne);

    document.getElementById("t-flareon").click();
    await flush();

    expect(document.getElementById("p-flareon").hidden).toBe(false);
    expect(document.getElementById("p-jolteon").hidden).toBe(true);
    expect(document.getElementById("t-flareon").classList.contains("is-active")).toBe(true);
    expect(document.getElementById("t-flareon").getAttribute("aria-pressed")).toBe("true");
    expect(document.getElementById("t-jolteon").classList.contains("is-active")).toBe(false);
    expect(document.getElementById("t-jolteon").getAttribute("aria-pressed")).toBe("false");
  });

  // The throne is one big progress tick, so picking a team must not also mark Blue beaten.
  it("keeps the click off the card the tabs sit on", async () => {
    await mount(throne);
    let reached = false;
    document.getElementById("card").addEventListener("click", () => { reached = true; });

    document.getElementById("t-flareon").click();
    await flush();

    expect(reached).toBe(false);
  });
});
