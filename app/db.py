"""Database engine + session setup (SQLAlchemy 2.0, sync).

Works with both SQLite (default, file-backed) and Postgres (DATABASE_URL).
"""
from __future__ import annotations

from collections.abc import Iterator

from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, Session, sessionmaker

from . import config


class Base(DeclarativeBase):
    pass


def _build_url() -> str:
    if config.DATABASE_URL:
        url = config.DATABASE_URL
        # Railway/Heroku hand out postg:// which SQLAlchemy wants as postgresql://
        if url.startswith("postgres://"):
            url = url.replace("postgres://", "postgresql://", 1)
        return url
    return f"sqlite:///{config.SQLITE_PATH}"


_url = _build_url()
_connect_args = {"check_same_thread": False} if _url.startswith("sqlite") else {}

engine = create_engine(
    _url,
    connect_args=_connect_args,
    pool_pre_ping=True,
    future=True,
)

SessionLocal = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)


def init_db() -> None:
    # Import models so they register on Base.metadata before create_all.
    from . import models  # noqa: F401

    Base.metadata.create_all(bind=engine)


def get_session() -> Iterator[Session]:
    """FastAPI dependency: yields a session and always closes it."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
