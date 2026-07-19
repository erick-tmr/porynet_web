"""Shared pytest fixtures for the map/scene generators.

The tests read the real pret/pokeyellow checkout (external to this repo). Point at it with
POKEYELLOW=<path>, or rely on the default ~/Code/pokeyellow; if it is not present the whole
suite skips rather than fails (e.g. in CI where the disassembly is not cloned)."""
import os
import pathlib
import sys

import pytest

TOOLS_DIR = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOLS_DIR))


@pytest.fixture(scope="session")
def root():
    path = pathlib.Path(os.environ.get("POKEYELLOW", "~/Code/pokeyellow")).expanduser()
    if not (path / "constants/map_constants.asm").exists():
        pytest.skip(f"pokeyellow checkout not found at {path} (set POKEYELLOW=<path>)")
    return str(path)
