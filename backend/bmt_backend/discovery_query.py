"""Current indexed-discovery filter contract."""
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field


class Query(BaseModel):
    model_config = ConfigDict(extra="forbid")
    search: str = Field("", max_length=80)
    search_kind: int = Field(0, ge=0, le=2)
    theme: str = Field("all", max_length=40)
    minimum_rating: float = Field(0, ge=0, le=5)
    age_days: int = Field(0, ge=0, le=36500)
    race_count: str = Field("any", pattern="^(any|low|medium|high)$")
    race_history: str = Field("any", pattern="^(any|raced|unraced)$")
    raced_ids: list[Annotated[str, Field(max_length=80)]] = Field(default_factory=list, max_length=50000)
    ids: list[Annotated[str, Field(max_length=80)]] | None = Field(None, max_length=50000)
    section: str = Field("all", pattern="^(all|favorites|saved)$")
    feed: str = Field("recommended", pattern="^(recommended|daily|new|popular|rated|trending)$")
    sort: str = Field("recommended", pattern="^(recommended|name|creator|score|plays|new)$")

