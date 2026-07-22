"""Unit tests for the per-map manifest diff CI renders on generator changes.

These build their manifests by hand, so unlike the rest of the suite they need no pokeyellow
checkout.
"""
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
