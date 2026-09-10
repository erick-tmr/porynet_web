import { Controller } from "@hotwired/stimulus"
import { load } from "lib/progress_store"
import { KEYS_PER_BATCH, batches, tally } from "lib/sync_payload"

const PHASES = [ "syncing", "done", "failed" ]

export default class extends Controller {
  static targets = [ "marks", "species", "pokemon", "sent", "total", "pct", "seconds", "attempt" ]

  static values = {
    game: { type: String, default: "yellow" },
    url: String,
    batchSize: { type: Number, default: KEYS_PER_BATCH },
    dismissMs: { type: Number, default: 30000 },
    tickMs: { type: Number, default: 250 },
    fade: { type: Number, default: 380 },
    attempts: { type: Number, default: 3 },
  }

  connect() {
    const state = load()
    this.queue = batches(state, this.gameValue, this.batchSizeValue)
    if (this.queue.length === 0) return

    this.at = 0
    this.sent = 0
    this.attempt = 1
    this.total = this.queue.reduce((records, batch) => records + batch.records, 0)
    this.#fill(tally(state, this.gameValue))
    this.element.hidden = false
    this.#run()
  }

  disconnect() {
    this.#stop()
  }

  retry() {
    if (this.attempt < this.attemptsValue) this.attempt += 1
    this.#run()
  }

  dismiss() {
    this.#stop()
    this.element.classList.add("is-gone")
    this.closer = setTimeout(() => { this.element.hidden = true }, this.fadeValue)
  }

  async #run() {
    this.#phase("syncing")
    this.#meter()
    const aborter = new AbortController()
    this.aborter = aborter

    while (this.at < this.queue.length) {
      const batch = this.queue[this.at]
      const landed = await this.#post(batch, aborter.signal)
      if (aborter.signal.aborted) return
      if (!landed) return this.#fail()

      this.at += 1
      this.sent += batch.records
      this.#meter()
    }
    this.#finish()
  }

  async #post({ collected, bodies }, signal) {
    const body = { collected, bodies, final: this.at === this.queue.length - 1 }
    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.#token(),
        },
        body: JSON.stringify(body),
        signal: signal,
      })
      return response.ok
    } catch {
      return false
    }
  }

  #token() {
    return document.querySelector("meta[name='csrf-token']")?.content || ""
  }

  #fail() {
    this.#phase("failed")
    this.attemptTargets.forEach((slot) => { slot.textContent = String(this.attempt) })
  }

  #finish() {
    this.#phase("done")
    const span = this.dismissMsValue
    const started = Date.now()
    this.#drain(span, span)
    this.ticker = setInterval(() => {
      const left = Math.max(0, span - (Date.now() - started))
      this.#drain(left, span)
      if (left === 0) this.dismiss()
    }, this.tickMsValue)
  }

  #drain(left, span) {
    this.element.style.setProperty("--pn-sync-drain", `${Math.round((left / span) * 100)}%`)
    this.secondsTargets.forEach((slot) => { slot.textContent = String(Math.ceil(left / 1000)) })
  }

  #meter() {
    const pct = Math.round((this.sent / this.total) * 100)
    this.element.style.setProperty("--pn-sync-pct", `${pct}%`)
    this.pctTargets.forEach((slot) => { slot.textContent = `${pct}%` })
    this.sentTargets.forEach((slot) => { slot.textContent = String(this.sent) })
  }

  #phase(name) {
    PHASES.forEach((phase) => {
      this.element.classList.toggle(`is-${phase}`, phase === name)
    })
  }

  #fill(counts) {
    this.marksTargets.forEach((slot) => { slot.textContent = String(counts.marks) })
    this.speciesTargets.forEach((slot) => { slot.textContent = String(counts.species) })
    this.pokemonTargets.forEach((slot) => { slot.textContent = String(counts.pokemon) })
    this.totalTargets.forEach((slot) => { slot.textContent = String(counts.records) })
  }

  #stop() {
    clearInterval(this.ticker)
    clearTimeout(this.closer)
    this.aborter?.abort()
  }
}
