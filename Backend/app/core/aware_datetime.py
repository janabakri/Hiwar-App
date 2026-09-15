"""Timezone-aware UTC DateTime column type.

SQLite (and some other storages) return offset-naive datetimes. Comparing them
with timezone-aware `datetime.now(timezone.utc)` values raises
`TypeError: can't compare offset-naive and offset-aware datetimes`.

`UTCDateTime` stores values as naive UTC in the database (same on-disk format
as before — no migration needed) and always returns timezone-aware UTC values
to the application, so every comparison is safe.
"""

from datetime import datetime, timezone

from sqlalchemy import DateTime
from sqlalchemy.types import TypeDecorator


class UTCDateTime(TypeDecorator):
    """A DateTime column that transparently normalizes to timezone-aware UTC."""

    impl = DateTime
    cache_ok = True

    def process_bind_param(self, value, dialect):
        if value is not None and value.tzinfo is not None:
            value = value.astimezone(timezone.utc).replace(tzinfo=None)
        return value

    def process_result_value(self, value, dialect):
        if value is not None and value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value


def utc_now() -> datetime:
    """Timezone-aware current UTC time — replacement for deprecated utcnow()."""
    return datetime.now(timezone.utc)
