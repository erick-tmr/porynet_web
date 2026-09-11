// PORYNET localdb console toolkit. Paste once per page load, then call porydb.<command>().
// Every write dispatches the store's own change event, so the page re-renders live.
window.porydb = (() => {
  const KEY = "porynet.progress";
  const GAME = "yellow";
  const empty = () => ({ v: 2, collected: {}, caught: {}, bodies: {} });
  const page = () => document.querySelector("[data-progress-state]");
  const adopted = () => page()?.dataset.progressAdopted === "true";

  const read = () => {
    try { return JSON.parse(localStorage.getItem(KEY)) || empty(); } catch { return empty(); }
  };

  const write = (state) => {
    if (adopted()) {
      console.warn("This trainer has synced: the save file is in charge and localdb is ignored. " +
        "Use porydb.push() to write to the account, or log out to go back to guest mode.");
    }
    localStorage.setItem(KEY, JSON.stringify(state));
    window.dispatchEvent(new CustomEvent("porynet:progress", { detail: { changed: {} } }));
    return porydb.show();
  };

  const count = (state, kind) => Object.keys(state[kind]?.[GAME] || {}).length;

  return {
    // ---- read ----
    show(game = GAME) {
      const local = read();
      const account = page() ? JSON.parse(page().dataset.progressState) : null;
      const row = (s) => s
        ? { marks: Object.keys(s.collected?.[game] || {}).length,
            species: Object.keys(s.bodies?.[game] || {}).length,
            bodies: Object.values(s.bodies?.[game] || {}).reduce((a, b) => a + b, 0) }
        : "none";
      console.table({ localdb: row(local), account: row(account) });
      return { renderingFrom: adopted() ? "the save file" : "localdb",
        schema: local.v, bytes: (localStorage.getItem(KEY) || "").length };
    },
    raw: () => localStorage.getItem(KEY),
    state: () => read(),
    marks: (game = GAME) => Object.keys(read().collected?.[game] || {}).sort(),
    species: (game = GAME) => read().bodies?.[game] || {},
    has: (id, game = GAME) => Boolean(read().collected?.[game]?.[id]),

    // ---- write ----
    mark(...ids) {
      const s = read();
      s.collected[GAME] = { ...(s.collected[GAME] || {}) };
      ids.flat().forEach((id) => { s.collected[GAME][id] = true; });
      return write(s);
    },
    unmark(...ids) {
      const s = read();
      s.collected[GAME] = { ...(s.collected[GAME] || {}) };
      ids.flat().forEach((id) => delete s.collected[GAME][id]);
      return write(s);
    },
    caught(dex, held = 1) {
      const s = read();
      s.caught[GAME] = { ...(s.caught[GAME] || {}), [dex]: held > 0 };
      s.bodies[GAME] = { ...(s.bodies[GAME] || {}), [dex]: held };
      if (held <= 0) { delete s.caught[GAME][dex]; delete s.bodies[GAME][dex]; }
      return write(s);
    },
    // Tick every markable thing the page in front of you is showing.
    markPage() {
      return this.mark([...document.querySelectorAll("[data-progress-id]")]
        .filter((el) => el.dataset.kind === "collected").map((el) => el.dataset.progressId));
    },
    wipe() {
      localStorage.removeItem(KEY);
      window.dispatchEvent(new CustomEvent("porynet:progress", { detail: { changed: {} } }));
      return "localdb wiped. Reload to see the page start clean.";
    },
    restore(json) { return write(typeof json === "string" ? JSON.parse(json) : json); },
    backup() { copy(localStorage.getItem(KEY)); return "localdb copied to clipboard"; },

    // ---- the account side ----
    async push(marks = {}, bodies = {}) {
      const url = document.querySelector("[data-progress-sync-url-value]")
        ?.dataset.progressSyncUrlValue;
      if (!url) return "not signed in on this page";
      const res = await fetch(url, { method: "PATCH",
        headers: { "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content },
        body: JSON.stringify({ marks, bodies }) });
      return `${res.status} ${res.statusText}`;
    },
  };
})();
porydb.show();
