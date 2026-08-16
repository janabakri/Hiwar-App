"""Small SQLite-safe schema additions for existing Hiwar installations."""
from sqlalchemy import inspect, text


def ensure_user_profile_columns(engine) -> None:
    inspector = inspect(engine)
    if "users" not in inspector.get_table_names():
        return
    existing = {column["name"] for column in inspector.get_columns("users")}
    additions = {
        "auth_provider": "VARCHAR(30) NOT NULL DEFAULT 'manual'",
        "auth_subject": "VARCHAR(255)",
        "age": "INTEGER",
        "education_level": "VARCHAR(80)",
        "certificates": "TEXT",
        "learning_reason": "TEXT",
        "profile_complete": "BOOLEAN NOT NULL DEFAULT 0",
    }
    with engine.begin() as connection:
        for name, definition in additions.items():
            if name not in existing:
                connection.execute(text(f"ALTER TABLE users ADD COLUMN {name} {definition}"))
