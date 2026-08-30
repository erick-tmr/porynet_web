import { Controller } from "@hotwired/stimulus"

// The Exp. All calculator. Gen 1 pays the item out in two passes (engine/battle/core.asm): the
// enemy's base exp is halved, that half is divided among the Pokemon that fought, and then the
// same routine runs again over the value it has already divided, so the party pass shares
// 50/fighters instead of the other 50. Whatever is left of that second half is paid to nobody.
//
// Every user-facing string is rendered server-side and only toggled here: the verdicts and the
// two-way legend lines sit in the DOM hidden, and the one word the amounts need ("nobody") rides
// in on a data attribute.
const HALF = 50

// A tick is only printed on a slice wide enough to hold it; the rest read off the legend.
const TICK_MIN = 11

export default class extends Controller {
  static targets = ["button", "seg", "segTick", "lostSeg", "handed", "tone", "amount",
                    "legendText", "verdict"]
  static values = { party: Number, fighters: Number }

  connect() {
    this.render()
  }

  pick(event) {
    const n = Number(event.currentTarget.dataset.n)
    if (event.currentTarget.dataset.key === "party") {
      this.partyValue = n
      if (this.fightersValue > n) this.fightersValue = n
    } else {
      this.fightersValue = n
      if (n > this.partyValue) this.partyValue = n
    }
    this.render()
  }

  render() {
    const party = this.partyValue
    const fighters = Math.min(this.fightersValue, party)
    const fighterShare = HALF / fighters
    const partyEach = HALF / (fighters * party)
    const handed = HALF + HALF / fighters
    const lost = 100 - handed
    const bench = party - fighters

    this.buttonTargets.forEach((button) => {
      const on = Number(button.dataset.n) === (button.dataset.key === "party" ? party : fighters)
      button.classList.toggle("is-active", on)
      button.setAttribute("aria-pressed", String(on))
    })

    this.segTargets.forEach((seg, i) => {
      const fought = i < fighters
      const pct = fought ? fighterShare + partyEach : partyEach
      seg.hidden = i >= party
      seg.style.setProperty("--w", `${pct}%`)
      seg.classList.toggle("is-bench", !fought)
      this.segTickTargets[i].textContent = pct >= TICK_MIN ? `${fmt(pct)}%` : ""
    })
    this.lostSegTarget.hidden = lost === 0
    this.lostSegTarget.style.setProperty("--w", `${lost}%`)

    this.handedTarget.textContent = fmt(handed)
    this.toneTarget.dataset.tone = tone(fighters)

    const amounts = {
      fighters: `${fighters} × ${fmt(fighterShare + partyEach)}%`,
      bench: bench === 0 ? null : `${bench} × ${fmt(partyEach)}%`,
      lost: `${fmt(lost)}%`,
    }
    this.amountTargets.forEach((node) => {
      node.textContent = amounts[node.dataset.row] ?? node.dataset.nobody
    })

    const states = { fighters: "any", bench: bench === 0 ? "none" : "some",
                     lost: lost === 0 ? "none" : "some" }
    this.legendTextTargets.forEach((node) => {
      node.hidden = node.dataset.state !== states[node.dataset.row]
    })
    this.verdictTargets.forEach((node) => {
      node.hidden = node.dataset.tone !== tone(fighters)
    })
  }
}

// One decimal, and no trailing zero on a whole number: 25, 8.3, 4.2.
function fmt(n) {
  const rounded = Math.round(n * 10) / 10
  return Number.isInteger(rounded) ? String(rounded) : rounded.toFixed(1)
}

// One fighter is the only case the game gets right; two is a quarter of the pot gone; more is a rout.
function tone(fighters) {
  if (fighters === 1) return "solo"
  return fighters === 2 ? "switch" : "crowd"
}
