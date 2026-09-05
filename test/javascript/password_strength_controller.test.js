import { Application } from "@hotwired/stimulus";
import { afterEach, beforeEach, describe, expect, it } from "vitest";
import PasswordStrengthController from "../../app/javascript/controllers/password_strength_controller.js";

const flush = () => new Promise((resolve) => setTimeout(resolve, 0));

let application;

const FIXTURE = `
  <form data-controller="password-strength" data-score="0">
    <input id="pw" type="password" data-password-strength-target="input"
           data-action="input->password-strength#check">
    <div id="length" data-password-strength-target="rule" data-rule="length"></div>
    <div id="mix" data-password-strength-target="rule" data-rule="mix"></div>
    <div id="unique" data-password-strength-target="rule" data-rule="unique"></div>
  </form>
`;

async function mount() {
  document.body.innerHTML = FIXTURE;
  application = Application.start();
  application.register("password-strength", PasswordStrengthController);
  await flush();
}

async function type(value) {
  const input = document.getElementById("pw");
  input.value = value;
  input.dispatchEvent(new Event("input", { bubbles: true }));
  await flush();
}

const score = () => document.querySelector("form").dataset.score;
const ok = (id) => document.getElementById(id).classList.contains("is-ok");

beforeEach(() => {
  document.body.innerHTML = "";
});

afterEach(() => {
  application?.stop();
});

describe("password_strength_controller", () => {
  it("scores nothing and passes no rule while the box is empty", async () => {
    await mount();
    await type("");

    expect(score()).toBe("0");
    expect(ok("length")).toBe(false);
    expect(ok("mix")).toBe(false);
    expect(ok("unique")).toBe(false);
  });

  it("counts length alone when the password is eight letters", async () => {
    await mount();
    await type("pikachuu");

    expect(score()).toBe("1");
    expect(ok("length")).toBe(true);
    expect(ok("mix")).toBe(false);
    expect(ok("unique")).toBe(false);
  });

  it("does not call digits alone a mix", async () => {
    await mount();
    await type("12345678");

    expect(score()).toBe("1");
    expect(ok("mix")).toBe(false);
  });

  it("adds a step once letters and digits are both there", async () => {
    await mount();
    await type("pikachu1");

    expect(score()).toBe("2");
    expect(ok("length")).toBe(true);
    expect(ok("mix")).toBe(true);
    expect(ok("unique")).toBe(false);
  });

  it("adds another step at twelve characters", async () => {
    await mount();
    await type("pikachu12345");

    expect(score()).toBe("3");
    expect(ok("unique")).toBe(true);
  });

  it("tops out when a symbol comes along", async () => {
    await mount();
    await type("pikachu12345!");

    expect(score()).toBe("4");
    expect(ok("length")).toBe(true);
    expect(ok("mix")).toBe(true);
    expect(ok("unique")).toBe(true);
  });

  it("drops back down when the password is cut short again", async () => {
    await mount();
    await type("pikachu12345!");
    await type("pika");

    expect(score()).toBe("0");
    expect(ok("length")).toBe(false);
  });
});
