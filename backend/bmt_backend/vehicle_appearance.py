"""Presentation-only car IDs and bounded pigments; never used in race contracts."""
import json
from pathlib import Path
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

CATALOG = json.loads(Path(__file__).with_name("vehicle_appearance_catalog.json").read_text(encoding="utf-8"))


class Cosmetic(BaseModel):
    model_config = ConfigDict(strict=True, extra="forbid", allow_inf_nan=False)

    @field_validator("version", mode="before", check_fields=False)
    @classmethod
    def integer_version(cls, value):
        if type(value) is not int:
            raise ValueError("Version must be an integer")
        return value


class Pigments(Cosmetic):
    body: str = Field(pattern=r"^[0-9a-f]{6}$")
    accent: str = Field(pattern=r"^[0-9a-f]{6}$")
    detail: str = Field(pattern=r"^[0-9a-f]{6}$")


class Sticker(Cosmetic):
    id: str = Field(min_length=1, max_length=40)
    x: float = Field(ge=0, le=1)
    y: float = Field(ge=0, le=1)
    size: float = Field(ge=0.2, le=0.95)
    rotation: float = Field(ge=-180, le=180)

    @field_validator("id")
    @classmethod
    def known_sticker(cls, value):
        if value not in CATALOG["stickers"]:
            raise ValueError("Unknown sticker")
        return value


class Panels(Cosmetic):
    hood: Sticker
    roof: Sticker


class Livery(Cosmetic):
    version: Literal[2]
    colors: Pigments
    pattern: str = Field(min_length=1, max_length=40)
    stickers: Panels

    @field_validator("pattern")
    @classmethod
    def known_pattern(cls, value):
        if value not in CATALOG["patterns"]:
            raise ValueError("Unknown pattern")
        return value


class Parts(Cosmetic):
    version: Literal[1]
    hood: str = Field(min_length=1, max_length=40)
    aero: str = Field(min_length=1, max_length=40)
    rims: str = Field(min_length=1, max_length=40)
    body: str = Field(min_length=1, max_length=40)

    @field_validator("hood", "aero", "rims", "body")
    @classmethod
    def known_part(cls, value, info):
        if value not in CATALOG["parts"][info.field_name]:
            raise ValueError("Unknown part")
        return value


class Appearance(Cosmetic):
    vehicle_id: Literal["compact", "pickup", "classic", "formula", "kart"]
    livery: Livery
    customisation: Parts

    @model_validator(mode="after")
    def fitted_parts(self):
        if self.vehicle_id != "compact" and any(v != "stock" for k, v in self.customisation.model_dump().items() if k != "version"):
            raise ValueError("Parts are fitted to Compact only")
        return self
