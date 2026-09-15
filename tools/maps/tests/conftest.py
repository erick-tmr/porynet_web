"""Shared pytest fixtures for the map/scene generators.

The tests read real disassembly checkouts (external to this repo). Point at each with its own
variable, or rely on the defaults below; one that is not present skips rather than fails (e.g.
in CI before the disassemblies are cloned). Most of the suite asserts Yellow's own content and
takes the `root` fixture; the golden manifest test runs for every game."""
import os
import pathlib
import sys

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))

import games  # noqa: E402  (the tools dir has to be on the path first)


def root_for(slug):
    """Where a game's disassembly is checked out, skipping the test when it is not there.

    Each game says which variable names its own checkout, so this and the build agree without
    either of them keeping a second list."""
    game = games.find(slug)
    path = pathlib.Path(os.environ.get(game.root_env, game.default_root)).expanduser()
    if not (path / "constants/map_constants.asm").exists():
        pytest.skip(f"{slug} checkout not found at {path} (set {game.root_env}=<path>)")
    return str(path)


@pytest.fixture(scope="session")
def root():
    """The game the suite's content tests are written against."""
    return root_for("yellow")
