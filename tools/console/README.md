# Browser console tools

Paste-into-the-console helpers for working on walkthrough progress. Nothing here ships: the app
never loads these files, and they are not on the asset path.

## `porydb.js`

Reads and writes the guest store (`localStorage["porynet.progress"]`). Paste it once per page
load, then call `porydb.<command>()`. Every write dispatches the store's own `porynet:progress`
event, so the page re-renders without a reload.

| | |
| --- | --- |
| `porydb.show()` | localdb against the account, and which one the page renders from |
| `porydb.marks()` / `porydb.species()` / `porydb.has(id)` | what is ticked |
| `porydb.mark(...ids)` / `porydb.unmark(...ids)` | tick and untick |
| `porydb.caught(dex, held)` | hold a species at a count, `0` releases |
| `porydb.markPage()` | tick everything the page in front of you shows |
| `porydb.wipe()` / `porydb.backup()` / `porydb.restore(json)` | start over, or carry a run around |
| `porydb.push(marks, bodies)` | PATCH the account directly, for a trainer who has synced |

Once a trainer has synced, `localStorage` is no longer read and the write commands say so. Change
a synced trainer through `porydb.push` or by clicking.

## `regenerate-seed.sh`

Writes `tmp/seed-run.js`, a console script that plants a part-finished run, for testing the sync
banner and the write-through without playing the game.

```sh
tools/console/regenerate-seed.sh        # 80%
tools/console/regenerate-seed.sh 0.25   # a quarter of the way in
```

The run is in walk order, so everything up to a point is ticked and the rest is left, which reads
like a real save rather than a random scatter. Seed it **logged out**: the banner reads
`localStorage` on the way in, so it has to be there before you sign in.

Ids come from the live model on every run rather than a list checked in beside it, so a seed
cannot point at a tick the walkthrough has since renamed. That is the failure the ids were given
names to avoid, so it would be a poor thing to reintroduce in the test fixtures.

It is a shell script wrapping `bin/rails runner -` rather than a `.rb` file because undercover
scans every changed Ruby file for coverage, and a generator the suite never runs has none to
give.
