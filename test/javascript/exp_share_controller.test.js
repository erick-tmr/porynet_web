import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import ExpShareController from "../../app/javascript/controllers/exp_share_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

async function mount(party = 6, fighters = 2) {
  document.body.innerHTML = fixture(party, fighters);
  application = Application.start();
  application.register("exp-share", ExpShareController);
  await flush();
}

// Six party slots and a lost remainder, the shape the partial renders.
const fixture = (party, fighters) => `
  <div data-controller="exp-share"
       data-exp-share-party-value="${party}" data-exp-share-fighters-value="${fighters}">
    ${[1, 2, 3, 4, 5, 6].map((n) => `
      <button data-exp-share-target="button" data-key="party" data-n="${n}"
              data-action="exp-share#pick" id="p${n}">${n}</button>`).join("")}
    ${[1, 2, 3, 4, 5, 6].map((n) => `
      <button data-exp-share-target="button" data-key="fighters" data-n="${n}"
              data-action="exp-share#pick" id="f${n}">${n}</button>`).join("")}
    <span data-exp-share-target="tone"><b data-exp-share-target="handed"></b></span>
    ${[0, 1, 2, 3, 4, 5].map((i) => `
      <span data-exp-share-target="seg" id="s${i}">
        <b data-exp-share-target="segTick"></b>
      </span>`).join("")}
    <span data-exp-share-target="lostSeg" id="lost"></span>
    <span data-exp-share-target="amount" data-row="fighters" data-nobody="nobody"></span>
    <span data-exp-share-target="amount" data-row="bench" data-nobody="nobody"></span>
    <span data-exp-share-target="amount" data-row="lost" data-nobody="nobody"></span>
    <span data-exp-share-target="legendText" data-row="bench" data-state="some">bench some</span>
    <span data-exp-share-target="legendText" data-row="bench" data-state="none">bench none</span>
    <span data-exp-share-target="legendText" data-row="lost" data-state="some">lost some</span>
    <span data-exp-share-target="legendText" data-row="lost" data-state="none">lost none</span>
    <span data-exp-share-target="legendText" data-row="fighters" data-state="any">fighters</span>
    <p data-exp-share-target="verdict" data-tone="solo">solo</p>
    <p data-exp-share-target="verdict" data-tone="switch">switch</p>
    <p data-exp-share-target="verdict" data-tone="crowd">crowd</p>
  </div>
`;

const el = (id) => document.getElementById(id);
const width = (id) => el(id).style.getPropertyValue("--w");
const tick = (i) => el(`s${i}`).querySelector("b").textContent;
const amount = (row) => document.querySelector(`[data-row='${row}'][data-exp-share-target='amount']`).textContent;
const shown = (sel) => [...document.querySelectorAll(sel)].filter((n) => !n.hidden).map((n) => n.textContent.trim());
const handed = () => document.querySelector("[data-exp-share-target='handed']").textContent;
const tone = () => document.querySelector("[data-exp-share-target='tone']").dataset.tone;

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("the pot as the game divides it", () => {
  // Two sent out of six: each fighter takes 25% of the halved pot plus a 4.2% party slice, the
  // four on the bench take 4.2% each, and the missing quarter is paid to nobody.
  it("splits a six-party, two-fighter battle the way engine/battle/core.asm does", async () => {
    await mount(6, 2);

    expect(handed()).toBe("75");
    expect(tone()).toBe("switch");
    expect(amount("fighters")).toBe("2 × 29.2%");
    expect(amount("bench")).toBe("4 × 4.2%");
    expect(amount("lost")).toBe("25%");
    expect(width("lost")).toBe("25%");
    expect(shown("[data-exp-share-target='verdict']")).toEqual(["switch"]);
  });

  // The one case the code gets right: the slice it copies is exactly the half it forgot to hand
  // out, so nothing is dropped.
  it("accounts for the whole pot with a single fighter", async () => {
    await mount(6, 1);

    expect(handed()).toBe("100");
    expect(tone()).toBe("solo");
    expect(amount("lost")).toBe("0%");
    expect(el("lost").hidden).toBe(true);
    expect(shown("[data-row='lost'][data-exp-share-target='legendText']")).toEqual(["lost none"]);
  });

  it("calls a crowded field what it is", async () => {
    await mount(6, 3);

    expect(tone()).toBe("crowd");
    expect(handed()).toBe("66.7");
    expect(shown("[data-exp-share-target='verdict']")).toEqual(["crowd"]);
  });

  it("says nobody is benched when the whole party is out", async () => {
    await mount(3, 3);

    expect(amount("bench")).toBe("nobody");
    expect(shown("[data-row='bench'][data-exp-share-target='legendText']")).toEqual(["bench none"]);
  });
});

describe("the bar", () => {
  it("draws one slice per party member and hides the empty slots", async () => {
    await mount(3, 1);

    expect(width("s0")).toBe("66.66666666666667%");
    expect(el("s0").classList.contains("is-bench")).toBe(false);
    expect(el("s1").classList.contains("is-bench")).toBe(true);
    expect(el("s2").hidden).toBe(false);
    expect(el("s3").hidden).toBe(true);
  });

  // A sliver has no room to print in, so it reads off the legend instead.
  it("only prints a tick on a slice wide enough to hold it", async () => {
    await mount(6, 2);

    expect(tick(0)).toBe("29.2%");
    expect(tick(5)).toBe("");
  });
});

describe("picking", () => {
  it("marks the chosen button in each group", async () => {
    await mount(6, 2);
    el("f3").click();
    await flush();

    expect(el("f3").classList.contains("is-active")).toBe(true);
    expect(el("f3").getAttribute("aria-pressed")).toBe("true");
    expect(el("f2").classList.contains("is-active")).toBe(false);
    expect(el("p6").classList.contains("is-active")).toBe(true);
  });

  it("leaves the fighters alone when the party still covers them", async () => {
    await mount(6, 2);
    el("p4").click();
    await flush();

    expect(el("p4").classList.contains("is-active")).toBe(true);
    expect(el("f2").classList.contains("is-active")).toBe(true);
    expect(amount("bench")).toBe("2 × 6.3%");
  });

  // The two controls cannot contradict each other: you cannot send out more than you carry.
  it("pulls the fighters down when the party shrinks below them", async () => {
    await mount(6, 4);
    el("p2").click();
    await flush();

    expect(el("p2").classList.contains("is-active")).toBe(true);
    expect(el("f2").classList.contains("is-active")).toBe(true);
    expect(amount("bench")).toBe("nobody");
  });

  it("pushes the party up when more are sent out than are carried", async () => {
    await mount(2, 1);
    el("f5").click();
    await flush();

    expect(el("p5").classList.contains("is-active")).toBe(true);
    expect(el("f5").classList.contains("is-active")).toBe(true);
    expect(tone()).toBe("crowd");
  });
});
