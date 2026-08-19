import dex
import sources


def test_snorlax_reads_the_screen_the_game_would_print(root):
    """The entry the S.S. Anne's 2F cabin fills in: species line, height, weight, type and the
    description, all of it lifted from the disassembly rather than typed."""
    entry = dex.build_dex(root)["143"]

    assert entry["name"] == "Snorlax"
    assert entry["species"] == "SLEEPING POKéMON"
    assert entry["types"] == ["NORMAL"]
    assert entry["height"] == "6'11\" (2.1 m)"
    assert entry["weight"] == "1014.0 lbs (459.9 kg)"
    assert entry["text"] == ("Will eat anything, even if the food happens to be a little moldy. "
                             "It never gets an upset stomach.")


def test_a_description_is_joined_back_into_one_paragraph(root):
    """The game stores a description as screen rows split over two pages. A row that ends mid
    sentence is continued by the next, and the page break is a scroll rather than a paragraph, so
    none of that punctuation may survive into the card."""
    for number, entry in dex.build_dex(root).items():
        text = entry["text"]

        assert "\n" not in text, number
        assert "  " not in text, number
        assert text.endswith((".", "!", "?")), number
        assert not text.startswith(" "), number


def test_the_line_break_abbreviation_is_spelled_out(root):
    """`#` is how the game fits POKé onto an eighteen-character row, split across the break or not.
    A paragraph has room for the whole word: Articuno's entry abbreviates it outright and Mew's
    breaks it in half."""
    built = dex.build_dex(root)

    for number in ("144", "151"):
        assert "#" not in built[number]["text"], number
    assert "POKéMON" in built["144"]["text"]
    assert "POKéMON" in built["151"]["text"]


def test_a_word_broken_over_a_row_keeps_its_hyphen(root):
    """The game cannot tell a break it inserted from a hyphen the word owns, so neither can this:
    healing every one of them would run Rhydon's 'harder-than-diamonds' together. Keeping it costs
    Mew a hyphen it does not want and keeps every real compound intact."""
    built = dex.build_dex(root)

    assert "micro-scope" in built["151"]["text"]
    assert "harder-than-diamonds" in built["091"]["text"]
    assert "nose-bending" in built["044"]["text"]


def test_a_block_closed_by_an_inline_terminator_still_ends(root):
    """Koffing's entry closes with a `@` inside its last row rather than with a `dex` macro. Read
    naively the block never ends and swallows every entry after it, so the count is the guard."""
    built = dex.build_dex(root)

    assert built["109"]["text"].endswith("Be very careful!")
    assert built["110"]["name"] == "Weezing"


def test_every_species_gets_an_entry(root):
    """All 151, Mew included: it is in the dex text like any other, whatever the glitch page has
    to say about catching one."""
    built = dex.build_dex(root)
    numbers = sources.parse_dex_numbers(root)

    assert len(numbers) == 151
    assert sorted(built) == [f"{n:03d}" for n in range(1, 152)]
    assert all(entry["types"] for entry in built.values()), "every entry names its type"
    # The three whose base stats file drops the underscore the species constant carries.
    assert built["029"]["types"] == ["POISON"] and built["122"]["types"] == ["PSYCHIC"]


def test_a_weight_under_a_pound_keeps_its_fraction(root):
    """Weights are tenths of a pound in the game, so most divide out whole. Gastly is 0.2 lbs and
    has to read that way rather than as 0 or 0.20000000001."""
    assert dex.build_dex(root)["092"]["weight"] == "0.2 lbs (0.1 kg)"


def test_metric_is_converted_from_the_game_rather_than_looked_up(root):
    """Gen 1 is imperial only, so the metric half is worked out from the cartridge's own figure.
    That is a rounding step behind the official dex wherever a species was designed in kilos and
    rounded into pounds: Snorlax is 460.0 kg there because it is really 1014.13 lbs, and 459.9 kg
    here because the game stored 1014.0. Lapras, a round 220.0 kg, comes out exact."""
    built = dex.build_dex(root)

    assert built["131"]["weight"] == "485.0 lbs (220.0 kg)"
    assert built["143"]["weight"].endswith("(459.9 kg)")
    assert built["019"]["height"] == "1'00\" (0.3 m)"
