"""Publication/read pins coordinate immutable storage with online garbage collection."""
from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class ObjectPin(Base):
    __tablename__ = "object_pins"
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    expires_at: Mapped[int] = mapped_column(Integer, index=True)
