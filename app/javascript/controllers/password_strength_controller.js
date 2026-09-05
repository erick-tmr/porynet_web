import { Controller } from "@hotwired/stimulus"

const RULES = {
  length: (value) => value.length >= 8,
  mix: (value) => /[0-9]/.test(value) && /[a-zA-Z]/.test(value),
  unique: (value) => value.length >= 12
}

export default class extends Controller {
  static targets = ["input", "rule"]

  check() {
    const value = this.inputTarget.value
    this.element.dataset.score = String(this.score(value))
    this.ruleTargets.forEach((rule) => {
      rule.classList.toggle("is-ok", RULES[rule.dataset.rule](value))
    })
  }

  score(value) {
    return [
      RULES.length(value),
      RULES.unique(value),
      RULES.mix(value),
      /[^a-zA-Z0-9]/.test(value)
    ].filter(Boolean).length
  }
}
