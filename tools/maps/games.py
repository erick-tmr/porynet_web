#!/usr/bin/env python3
"""Which game a build is of, and everything that follows from that.

The renderer is generic across Gen 1: it reads a disassembly and draws what is in it. What is
*not* generic is where the output goes and what it is called, and that used to be a column of
constants with `yellow` written into each one. A second game needs its own images, its own
manifests and its own specs sitting beside the first game's, so those names become a profile
and the build is handed one.

The disassembly root is not part of the profile. It is where a particular checkout happens to
live on a particular machine, which is a fact about the machine rather than about the game, so
it stays a command-line argument.
"""
import dataclasses
import pathlib

REPO = pathlib.Path(__file__).resolve().parents[2]
TOOLS = pathlib.Path(__file__).resolve().parent


@dataclasses.dataclass(frozen=True)
class Game:
    slug: str
    source: str
    follower: str | None
    # Where this game's checkout lives: the variable that names it, and where to look otherwise.
    root_env: str
    default_root: str
    # The game whose images this one falls back to, when a picture comes out the same in both.
    shares_images_with: str | None = None

    @property
    def repo(self):
        return f"https://github.com/{self.source}"

    @property
    def ref_file(self):
        """The commit this game is pinned to, so CI builds against a disassembly we have read."""
        return TOOLS / f".{self.slug}-ref"

    @property
    def ref(self):
        return self.ref_file.read_text().strip()

    @property
    def image_prefix(self):
        """The R2 key prefix, which is also the path under app/assets/images."""
        return f"walkthrough/{self.slug}"

    @property
    def image_root(self):
        return REPO / "app/assets/images" / self.image_prefix

    @property
    def specs_dir(self):
        return TOOLS / "specs" / self.slug

    @property
    def report(self):
        return TOOLS / f"REPORT-{self.slug}.md"

    def data(self, name):
        """One of the JSON artefacts the Rails side reads, e.g. data("maps")."""
        return REPO / "app/models/walkthrough" / f"{self.slug.replace('-', '_')}_{name}.json"


CATALOGUE = {
    "yellow": Game(slug="yellow", source="pret/pokeyellow", follower="SPRITE_PIKACHU",
                   root_env="POKEYELLOW", default_root="~/Code/pokeyellow"),
    "yellow-legacy": Game(slug="yellow-legacy",
                          source="cRz-Shadows/Pokemon_Yellow_Legacy",
                          follower="SPRITE_PIKACHU",
                          root_env="YELLOW_LEGACY",
                          default_root="~/Code/Pokemon_Yellow_Legacy",
                          shares_images_with="yellow"),
}


def find(slug):
    try:
        return CATALOGUE[slug]
    except KeyError:
        raise SystemExit(f"unknown game {slug!r}; known: {', '.join(CATALOGUE)}") from None
