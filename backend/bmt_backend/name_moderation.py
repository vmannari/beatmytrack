"""Bounded, local checks for user-chosen public names, without rewriting them.

Word lists and the reviewed exceptions ship with the package. Names are never
sent to a provider or retained in a cache. Reports/searches are not naming writes.
"""
from __future__ import annotations

import json
import re
import unicodedata
from itertools import groupby
from pathlib import Path

from fastapi import HTTPException
from pydantic_core import PydanticCustomError

DATA = Path(__file__).with_name("name_filter_data")
REJECTION = "NAME_NOT_ALLOWED: Please choose another name."
MAX_NAME_LENGTH = 512
_WORDS = re.compile(r"[^\W_]+", re.UNICODE)
_REPEATS = re.compile(r"(.)\1+", re.DOTALL)
_LONG_REPEATS = re.compile(r"(.)\1{2,}", re.DOTALL)
_MASKED = re.compile(r"f\*+c?k|sh\*+t|b\*+tch|c\*+nt|n\*+gg(?:er|a)")
# Common visual substitutions, rather than transliteration of whole languages.
_CONFUSABLES = str.maketrans({
    "а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "х": "x", "у": "y",
    "і": "i", "ј": "j", "ѕ": "s", "һ": "h", "ӏ": "l",
    "α": "a", "ε": "e", "ι": "i", "ο": "o", "ρ": "p", "τ": "t", "υ": "u",
    "χ": "x", "ϲ": "c", "ı": "i", "ս": "u",
})
_LEET = str.maketrans("01345789@$!|+", "oieastbgasiit")
_LEET_L = {**_LEET, ord("1"): "l", ord("|"): "l"}


def _fold(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).casefold()
    value = unicodedata.normalize("NFKD", value)
    return "".join(c for c in value if unicodedata.category(c) not in ("Mn", "Me", "Cf")).translate(_CONFUSABLES)


def _tokens(value: str) -> tuple[str, ...]:
    return tuple(_WORDS.findall(value))


def _load():
    policy = json.loads((DATA / "policy.json").read_text(encoding="utf-8"))
    sources = json.loads((DATA / "sources.json").read_text(encoding="utf-8"))["sources"]
    excluded = {_tokens(_fold(term)) for term in policy["excluded_terms"]}
    terms, unsegmented = set(), set()
    for language in sources:
        if language == "LICENSE":
            continue
        for term in (DATA / (language + ".txt")).read_text(encoding="utf-8").splitlines():
            words = _tokens(_fold(term))
            if not words or words in excluded:
                continue
            # One-character entries are too ambiguous for public names.
            if sum(map(len, words)) < 2:
                continue
            terms.add(words)
            if language in ("ja", "zh", "th") and any(
                "\u0e00" <= c <= "\u0e7f" or "\u3040" <= c <= "\u30ff" or "\u3400" <= c <= "\u9fff"
                for c in "".join(words)
            ):
                unsegmented.add("".join(words))
    terms.update(_tokens(_fold(term)) for term in policy["additional_terms"])
    roots = frozenset("".join(_tokens(_fold(term))) for term in policy["embedded_roots"])
    return (frozenset(terms), frozenset(unsegmented), roots, max(map(len, terms)), policy["version"])


_TERMS, _UNSEGMENTED, _ROOTS, _MAX_PHRASE, POLICY_VERSION = _load()
# Preserve required double letters (e.g. Niger is a country), while accepting
# extra repeated letters. Adjacent groups always contain different literals.
_ROOT_PATTERNS = tuple(re.compile("".join(
    re.escape(char) + "{" + str(len(list(run))) + ",}" for char, run in groupby(root)
)) for root in _ROOTS)


def contains_profanity(value: str) -> bool:
    """Check a bounded name, including common spacing, leet and Unicode disguises."""
    if len(value) > MAX_NAME_LENGTH:
        raise ValueError("Name exceeds the supported comparison length")
    folded = _fold(value)
    if len(folded) > MAX_NAME_LENGTH * 4:
        raise ValueError("Name expands beyond the supported comparison length")
    if _MASKED.search(folded):
        return True
    for text in {folded, folded.translate(_LEET), folded.translate(_LEET_L)}:
        for variant in {text, _REPEATS.sub(r"\1", text), _LONG_REPEATS.sub(r"\1\1", text)}:
            words = _tokens(variant)
            compact = "".join(words)
            # Only reviewed, unambiguous roots match inside compound usernames.
            if any(pattern.search(compact) for pattern in _ROOT_PATTERNS):
                return True
            if any(term in compact for term in _UNSEGMENTED):
                return True
            for start, word in enumerate(words):
                if (word.strip("0123456789"),) in _TERMS:
                    return True
                for length in range(1, min(_MAX_PHRASE, len(words) - start) + 1):
                    if words[start:start + length] in _TERMS:
                        return True
                # Split-letter disguises: s.h.i.t, sh-it, c_u_n_t, etc.
                joined = ""
                for part in words[start:]:
                    if len(part) > 2 or len(joined) + len(part) > 32:
                        break
                    joined += part
                    if (joined,) in _TERMS:
                        return True
    return False


def validate_name(value: str) -> str:
    """Pydantic hook; keep the original accepted name and immutable hashes."""
    if contains_profanity(value):
        raise PydanticCustomError("inappropriate_name", REJECTION)
    return value


def validate_track_document(document: dict) -> dict:
    """The downloadable document has its own name, independent of its envelope."""
    name = document.get("name")
    if isinstance(name, str):
        validate_name(name)
    return document


def require_allowed_names(*values: str) -> None:
    """Check names inherited from older rows before creating new public content."""
    try:
        rejected = any(contains_profanity(value) for value in values)
    except ValueError:
        raise HTTPException(422, "INVALID_INPUT") from None
    if rejected:
        raise HTTPException(422, REJECTION)


def require_allowed_track_names(name: str, document: dict, creator: str) -> None:
    """Used after exact receipt recovery and before new storage/publication."""
    names = [name, creator]
    if isinstance(document.get("name"), str):
        names.append(document["name"])
    require_allowed_names(*names)
