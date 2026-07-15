import { Controller } from "@hotwired/stimulus"

// Drives the Oak Challenge city stepper. The full city data is passed in via the
// cities value (JSON), so clicking a city updates the stat panel without a
// round-trip. The initial index is server-rendered and reconciled on connect.
export default class extends Controller {
  static targets = ["button", "name", "total", "oak", "dex", "newMons"]
  static values = { cities: Array, index: { type: Number, default: 0 } }

  select(event) {
    this.indexValue = Number(event.currentTarget.dataset.cityIndex)
  }

  indexValueChanged() {
    const city = this.citiesValue[this.indexValue]
    if (!city) return

    this.buttonTargets.forEach((btn) => {
      btn.classList.toggle("is-active", Number(btn.dataset.cityIndex) === this.indexValue)
    })

    if (this.hasNameTarget) this.nameTarget.textContent = city.name
    if (this.hasTotalTarget) this.totalTarget.textContent = city.total
    if (this.hasOakTarget) this.oakTarget.textContent = city.oak
    if (this.hasDexTarget) this.dexTarget.textContent = city.dex
    if (this.hasNewMonsTarget) this.#renderMons(city.new_mons)
  }

  #renderMons(mons) {
    this.newMonsTarget.replaceChildren(
      ...mons.map((mon) => {
        const pill = document.createElement("span")
        pill.className = "pn-mon"
        const dot = document.createElement("span")
        dot.className = "pn-mon__dot"
        pill.appendChild(dot)
        pill.appendChild(document.createTextNode(mon))
        return pill
      })
    )
  }
}
