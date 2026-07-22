"""Unit tests for the per-map manifest diff CI renders on generator changes.

These build their manifests by hand, so unlike the rest of the suite they need no pokeyellow
checkout.
"""
import io
import json

import manifest_diff


def marker(marker_id, cat="hidden", ref="POTION", grid=(4, 5), x=10.0, y=20.0, name="Potion"):
    return {"id": marker_id, "cat": cat, "ref": ref, "grid": list(grid),
            "x": x, "y": y, "name": name}


def manifest(*entries):
    return {"source": "pret/pokeyellow", "locations": {"pallet-town": list(entries)}}


def entry(name="pallet-town", width=320, height=288, markers=()):
    return {"image": f"walkthrough/yellow/maps/{name}.png", "width": width, "height": height,
            "floor": "", "name": name, "markers": list(markers)}


def test_identical_manifests_produce_no_deltas():
    same = manifest(entry(markers=[marker("hidden-4-5")]))
    assert manifest_diff.diff_manifests(same, same) == []


def test_added_marker():
    old = manifest(entry(markers=[marker("hidden-4-5")]))
    new = manifest(entry(markers=[marker("hidden-4-5"), marker("item-9-9", cat="item", ref="NUGGET")]))

    delta, = manifest_diff.diff_manifests(old, new)
    assert delta.name == "pallet-town" and delta.status == "changed"
    assert [m["id"] for m in delta.added] == ["item-9-9"]
    assert delta.removed == [] and delta.moved == []


def test_removed_marker():
    old = manifest(entry(markers=[marker("hidden-4-5"), marker("item-9-9", cat="item", ref="NUGGET")]))
    new = manifest(entry(markers=[marker("hidden-4-5")]))

    delta, = manifest_diff.diff_manifests(old, new)
    assert [m["id"] for m in delta.removed] == ["item-9-9"]
    assert delta.added == [] and delta.moved == []


def test_stable_id_that_changes_position_is_a_move():
    old = manifest(entry(markers=[marker("exit-north", cat="exit", grid=(1, 0))]))
    new = manifest(entry(markers=[marker("exit-north", cat="exit", grid=(3, 0))]))

    delta, = manifest_diff.diff_manifests(old, new)
    (before, after), = delta.moved
    assert before["grid"] == [1, 0] and after["grid"] == [3, 0]
    assert delta.added == [] and delta.removed == []


def test_grid_encoded_id_that_shifts_is_repaired_into_a_move():
    old = manifest(entry(markers=[marker("hidden-4-5", grid=(4, 5))]))
    new = manifest(entry(markers=[marker("hidden-6-5", grid=(6, 5))]))

    delta, = manifest_diff.diff_manifests(old, new)
    (before, after), = delta.moved
    assert before["id"] == "hidden-4-5" and after["id"] == "hidden-6-5"
    assert delta.added == [] and delta.removed == []


def test_ambiguous_identity_stays_an_add_and_a_remove():
    old = manifest(entry(markers=[marker("hidden-1-1", grid=(1, 1)), marker("hidden-2-2", grid=(2, 2))]))
    new = manifest(entry(markers=[marker("hidden-3-3", grid=(3, 3))]))

    delta, = manifest_diff.diff_manifests(old, new)
    assert delta.moved == []
    assert sorted(m["id"] for m in delta.removed) == ["hidden-1-1", "hidden-2-2"]
    assert [m["id"] for m in delta.added] == ["hidden-3-3"]


def test_resized_map_is_reported():
    old = manifest(entry(width=320, height=288))
    new = manifest(entry(width=800, height=576))

    delta, = manifest_diff.diff_manifests(old, new)
    assert delta.resized == ((320, 288), (800, 576))


def test_whole_map_added_and_removed():
    old = manifest(entry(name="pallet-town", markers=[marker("hidden-4-5")]))
    new = manifest(entry(name="viridian-city", markers=[marker("hidden-4-5")]))

    by_name = {d.name: d for d in manifest_diff.diff_manifests(old, new)}
    assert by_name["pallet-town"].status == "removed"
    assert by_name["viridian-city"].status == "added"
    assert len(by_name["viridian-city"].added) == 1


def test_render_markdown_with_no_deltas():
    assert "byte-identical" in manifest_diff.render_markdown([])


def test_render_markdown_lists_every_change_kind():
    old = manifest(entry(width=320, markers=[
        marker("hidden-4-5", grid=(4, 5)),
        marker("exit-north", cat="exit", ref="ROUTE_1", grid=(1, 0)),
        marker("item-9-9", cat="item", ref="NUGGET")]))
    new = manifest(entry(width=800, markers=[
        marker("hidden-6-5", grid=(6, 5)),
        marker("exit-north", cat="exit", ref="ROUTE_1", grid=(3, 0)),
        marker("trainer-2-2", cat="trainer", ref="OPP_YOUNGSTER")]))

    out = manifest_diff.render_markdown(manifest_diff.diff_manifests(old, new))
    assert "**1 map(s) changed.**" in out
    assert "| `pallet-town` | changed |" in out
    assert "resized 320x288 -> 800x288" in out
    assert "moved `hidden-4-5` [4,5]" in out and "-> `hidden-6-5` [6,5]" in out
    assert "moved `exit-north` [1,0]" in out
    assert "added `trainer-2-2`" in out
    assert "removed `item-9-9`" in out


def test_render_markdown_omits_the_size_line_when_only_markers_changed():
    old = manifest(entry(markers=[marker("hidden-4-5")]))
    new = manifest(entry(markers=[marker("hidden-4-5"), marker("item-9-9", cat="item", ref="NUGGET")]))

    out = manifest_diff.render_markdown(manifest_diff.diff_manifests(old, new))
    assert "resized" not in out
    assert "added `item-9-9`" in out


def test_describe_marker_without_grid_or_name():
    bare = {"id": "hidden-0-0", "cat": "hidden", "ref": None, "name": None}
    assert manifest_diff._describe(bare) == "`hidden-0-0` ?"


def test_parse_declared_reads_every_trailer_in_a_log():
    log = """fix(maps): put Route 22's west exit inside its strip

Manifest-drift: route-22, viridian-city

Co-Authored-By: someone <a@b.c>

chore(maps): rebuild after the fix

  manifest-drift:  route-2
"""
    assert manifest_diff.parse_declared(log) == {"route-22", "viridian-city", "route-2"}


def test_parse_declared_ignores_a_log_without_trailers():
    assert manifest_diff.parse_declared("fix: something unrelated\n\nBody text.") == set()
    assert manifest_diff.parse_declared("") == set()
    assert manifest_diff.parse_declared(None) == set()


def test_parse_declared_ignores_a_mid_line_mention():
    """Only a real trailer counts, so prose about the convention cannot declare a map."""
    assert manifest_diff.parse_declared("We should add a Manifest-drift: trailer someday.") == set()


def test_check_drift_agrees_when_the_sets_match():
    deltas = [manifest_diff.MapDelta(name="route-22")]
    assert manifest_diff.check_drift(deltas, {"route-22"}) == ([], [])


def test_check_drift_reports_undeclared_movement():
    deltas = [manifest_diff.MapDelta(name="route-22"), manifest_diff.MapDelta(name="viridian-city")]
    undeclared, unmoved = manifest_diff.check_drift(deltas, {"route-22"})
    assert undeclared == ["viridian-city"] and unmoved == []


def test_check_drift_reports_a_declaration_that_did_not_move():
    deltas = [manifest_diff.MapDelta(name="route-22")]
    undeclared, unmoved = manifest_diff.check_drift(deltas, {"route-22", "pallet-town"})
    assert undeclared == [] and unmoved == ["pallet-town"]


def test_check_drift_accepts_all_as_a_wholesale_regeneration():
    deltas = [manifest_diff.MapDelta(name=f"map-{n}") for n in range(97)]
    assert manifest_diff.check_drift(deltas, {"all"}) == ([], [])


def test_render_verdict_wording():
    assert "matches" in manifest_diff.render_verdict([], [])
    assert "moved without being declared" in manifest_diff.render_verdict(["route-2"], [])
    assert "declared but unchanged" in manifest_diff.render_verdict([], ["pallet-town"])


def _write(tmp_path, name, payload):
    path = tmp_path / name
    path.write_text(json.dumps(payload))
    return str(path)


def test_main_without_expectations_only_reports(tmp_path, capsys):
    old = _write(tmp_path, "base.json", manifest(entry(markers=[marker("hidden-4-5")])))
    new = _write(tmp_path, "head.json", manifest(entry(markers=[])))

    assert manifest_diff.main([old, new]) == 0
    assert "Declared drift" not in capsys.readouterr().out


def test_main_passes_when_the_declared_set_matches(tmp_path, capsys):
    old = _write(tmp_path, "base.json", manifest(entry(markers=[marker("hidden-4-5")])))
    new = _write(tmp_path, "head.json", manifest(entry(markers=[])))

    assert manifest_diff.main([old, new, "--expect", "pallet-town"]) == 0
    assert "Declared drift (`pallet-town`)" in capsys.readouterr().out


def test_main_fails_on_undeclared_movement(tmp_path, capsys):
    old = _write(tmp_path, "base.json", manifest(entry(markers=[marker("hidden-4-5")])))
    new = _write(tmp_path, "head.json", manifest(entry(markers=[])))

    assert manifest_diff.main([old, new, "--expect", "route-22"]) == 1
    out = capsys.readouterr().out
    assert "moved without being declared" in out and "`pallet-town`" in out


def test_main_reads_trailers_from_a_commit_log_file(tmp_path):
    old = _write(tmp_path, "base.json", manifest(entry(markers=[marker("hidden-4-5")])))
    new = _write(tmp_path, "head.json", manifest(entry(markers=[])))
    log = tmp_path / "commits.txt"
    log.write_text("fix(maps): drop a stale marker\n\nManifest-drift: pallet-town\n")

    assert manifest_diff.main([old, new, "--expect-commits", str(log)]) == 0


def test_main_reads_trailers_from_stdin(tmp_path, monkeypatch):
    old = _write(tmp_path, "base.json", manifest(entry(markers=[marker("hidden-4-5")])))
    new = _write(tmp_path, "head.json", manifest(entry(markers=[])))
    monkeypatch.setattr("sys.stdin", io.StringIO("Manifest-drift: pallet-town\n"))

    assert manifest_diff.main([old, new, "--expect-commits", "-"]) == 0


def test_main_fails_when_a_trailer_names_a_map_that_did_not_move(tmp_path, capsys):
    same = manifest(entry(markers=[marker("hidden-4-5")]))
    old = _write(tmp_path, "base.json", same)
    new = _write(tmp_path, "head.json", same)

    assert manifest_diff.main([old, new, "--expect", "pallet-town"]) == 1
    assert "declared but unchanged" in capsys.readouterr().out
