import { afterEach, describe, expect, it } from "vitest";
import { token } from "../../app/javascript/lib/csrf.js";

afterEach(() => {
  document.head.innerHTML = "";
});

describe("csrf", () => {
  it("reads the token the page carries", () => {
    document.head.innerHTML = '<meta name="csrf-token" content="abc123">';

    expect(token()).toBe("abc123");
  });

  it("hands back an empty token rather than nothing when the page carries none", () => {
    expect(token()).toBe("");
  });
});
