"""Where a build's output lands, which is the one thing that is not read out of the game."""
import pytest

import games


def test_every_game_puts_its_images_under_its_own_prefix():
    prefixes = {game.image_prefix for game in games.CATALOGUE.values()}
    assert len(prefixes) == len(games.CATALOGUE), "two games would overwrite each other's images"
    assert prefixes == {f"walkthrough/{slug}" for slug in games.CATALOGUE}


def test_the_image_prefix_is_also_the_path_the_pngs_are_written_to():
    """The R2 key and the on-disk path are the same string by construction, because the upload
    takes the object key from the path relative to app/assets/images."""
    yellow = games.find("yellow")
    assert yellow.image_root.as_posix().endswith(f"app/assets/images/{yellow.image_prefix}")


def test_a_json_artefact_is_named_for_its_game_in_the_shape_rails_reads():
    assert games.find("yellow").data("maps").name == "yellow_maps.json"
    assert games.find("yellow-legacy").data("maps").name == "yellow_legacy_maps.json"


def test_every_game_keeps_its_own_specs_and_its_own_report():
    yellow, legacy = games.find("yellow"), games.find("yellow-legacy")
    assert yellow.specs_dir != legacy.specs_dir
    assert yellow.report != legacy.report, "one report would clobber the other"
    assert yellow.specs_dir.name == "yellow"


def test_every_game_credits_the_disassembly_it_was_built_from():
    """The manifests carry this into the repo, so a reader can tell which game a file describes
    and which project to credit for it."""
    assert games.find("yellow").source == "pret/pokeyellow"
    assert games.find("yellow-legacy").source == "cRz-Shadows/Pokemon_Yellow_Legacy"


def test_the_whole_family_trails_pikachu():
    assert {game.follower for game in games.CATALOGUE.values()} == {"SPRITE_PIKACHU"}


def test_an_unknown_game_names_the_ones_that_exist():
    with pytest.raises(SystemExit, match="unknown game 'crystal'.*yellow"):
        games.find("crystal")


def test_a_game_sharing_images_names_one_that_exists():
    """A typo here would not fail the build: every frame would simply miss the base game's file
    and be written under this game's own prefix, quietly doubling the bucket."""
    for game in games.CATALOGUE.values():
        if game.shares_images_with:
            assert game.shares_images_with in games.CATALOGUE, game.slug


def test_no_game_shares_images_with_itself_or_a_sharer():
    """Sharing is one hop: the base game has to be one that writes every frame it renders, or a
    shared key could point at a file that was itself deduplicated away."""
    for game in games.CATALOGUE.values():
        assert game.shares_images_with != game.slug
        if game.shares_images_with:
            assert games.find(game.shares_images_with).shares_images_with is None, game.slug
