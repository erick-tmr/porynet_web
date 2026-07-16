import { Controller } from "@hotwired/stimulus"

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
        const thumb = document.createElement("span")
        thumb.className = "pn-mon__thumb"
        const img = document.createElement("img")
        img.src = mon.sprite
        img.alt = ""
        thumb.appendChild(img)
        pill.appendChild(thumb)
        pill.appendChild(document.createTextNode(mon.name))
        return pill
      })
    )
  }
}
