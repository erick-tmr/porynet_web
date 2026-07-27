import { Controller } from "@hotwired/stimulus"

// Level calculator on the Mew glitch page. Picking the last opponent's Attack stat stage
// (-6..+6) sets the level Mew spawns at: the game stores stages as 1-13, so a neutral stage
// (baseline 7) yields Lv 7 and each Growl drops it one. All 13 recipe lines are rendered
// server-side (localized) and just toggled here, keeping the copy in the locale files.
export default class extends Controller {
  static targets = ["button", "recipe", "level"]
  static values = { stage: Number, baseline: Number }

  pick(event) {
    this.stageValue = Number(event.currentTarget.dataset.stage)
  }

  stageValueChanged() {
    const stage = this.stageValue
    const level = String(this.baselineValue + stage)
    this.buttonTargets.forEach((button) => {
      button.classList.toggle("is-active", Number(button.dataset.stage) === stage)
    })
    this.recipeTargets.forEach((recipe) => {
      recipe.hidden = Number(recipe.dataset.stage) !== stage
    })
    this.levelTargets.forEach((readout) => {
      readout.textContent = level
    })
  }
}
