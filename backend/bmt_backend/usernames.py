"""Stable comparison rules for unique racing names, independent of player UUIDs."""

import unicodedata


def username_key(name: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", name).split()).casefold()


DEVELOPER_NAME = "Beat My Track"
DEVELOPER_NAME_KEY = username_key(DEVELOPER_NAME)
