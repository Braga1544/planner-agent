"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-10-09
"""

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

TS = sa.DateTime(timezone=True)
UUID = postgresql.UUID(as_uuid=True)


def _id() -> sa.Column:
    return sa.Column("id", UUID, primary_key=True, server_default=sa.text("gen_random_uuid()"))


def _timestamps() -> list[sa.Column]:
    return [
        sa.Column("created_at", TS, nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", TS, nullable=False, server_default=sa.func.now()),
    ]


def _area(nullable: bool) -> sa.Column:
    return sa.Column("area", sa.String(40), sa.ForeignKey("areas.slug"), nullable=nullable)


def upgrade() -> None:
    areas = op.create_table(
        "areas",
        sa.Column("slug", sa.String(40), primary_key=True),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("position", sa.Integer, nullable=False),
    )
    op.bulk_insert(
        areas,
        [
            {"slug": "work", "name": "Arbeit", "position": 1},
            {"slug": "business", "name": "Business", "position": 2},
            {"slug": "hobby", "name": "Hobby", "position": 3},
            {"slug": "personal", "name": "Privat", "position": 4},
        ],
    )

    op.create_table(
        "projects",
        _id(),
        _area(nullable=False),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("description", sa.Text),
        sa.Column("status", sa.String(20), nullable=False, server_default="active"),
        *_timestamps(),
        sa.CheckConstraint("status IN ('active','paused','done','archived')", name="ck_projects_status"),
    )

    op.create_table(
        "items",
        _id(),
        _area(nullable=False),
        sa.Column("project_id", UUID, sa.ForeignKey("projects.id", ondelete="SET NULL")),
        sa.Column("type", sa.String(10), nullable=False),
        sa.Column("title", sa.String(300), nullable=False),
        sa.Column("body", sa.Text),
        sa.Column("status", sa.String(10), nullable=False, server_default="open"),
        sa.Column("priority", sa.String(10), nullable=False, server_default="normal"),
        sa.Column("due_date", sa.Date),
        sa.Column("completed_at", TS),
        *_timestamps(),
        sa.CheckConstraint("type IN ('todo','idea','note')", name="ck_items_type"),
        sa.CheckConstraint("status IN ('open','done','archived')", name="ck_items_status"),
        sa.CheckConstraint("priority IN ('low','normal','high')", name="ck_items_priority"),
        sa.CheckConstraint("due_date IS NULL OR type = 'todo'", name="ck_items_due_only_todo"),
    )

    op.create_table(
        "calendar_sources",
        _id(),
        sa.Column("name", sa.String(200), nullable=False),
        sa.Column("url", sa.Text, nullable=False),
        _area(nullable=True),
        sa.Column("enabled", sa.Boolean, nullable=False, server_default=sa.true()),
        sa.Column("last_synced_at", TS),
        sa.Column("last_error", sa.Text),
        *_timestamps(),
    )

    op.create_table(
        "events",
        _id(),
        sa.Column("title", sa.String(300), nullable=False),
        sa.Column("location", sa.Text),
        sa.Column("notes", sa.Text),
        sa.Column("start_at", TS, nullable=False),
        sa.Column("end_at", TS),
        sa.Column("all_day", sa.Boolean, nullable=False, server_default=sa.false()),
        sa.Column("rrule", sa.Text),
        _area(nullable=True),
        sa.Column("project_id", UUID, sa.ForeignKey("projects.id", ondelete="SET NULL")),
        sa.Column("reminder_minutes", sa.Integer),
        sa.Column("source", sa.String(20), nullable=False, server_default="local"),
        sa.Column("calendar_source_id", UUID, sa.ForeignKey("calendar_sources.id", ondelete="CASCADE")),
        sa.Column("external_id", sa.Text),
        sa.Column("deleted_at", TS),
        *_timestamps(),
        sa.CheckConstraint("source IN ('local','ics_import','device')", name="ck_events_source"),
        sa.UniqueConstraint("calendar_source_id", "external_id", name="uq_events_source_external"),
    )
    op.create_index("ix_events_start_at", "events", ["start_at"])

    op.create_table(
        "conversations",
        _id(),
        sa.Column("title", sa.String(200)),
        *_timestamps(),
    )

    op.create_table(
        "messages",
        _id(),
        sa.Column(
            "conversation_id", UUID, sa.ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False
        ),
        sa.Column("seq", sa.Integer, nullable=False),
        sa.Column("role", sa.String(10), nullable=False),
        sa.Column("content", postgresql.JSONB, nullable=False),
        sa.Column("usage", postgresql.JSONB),
        sa.Column("created_at", TS, nullable=False, server_default=sa.func.now()),
        sa.CheckConstraint("role IN ('user','assistant')", name="ck_messages_role"),
        sa.UniqueConstraint("conversation_id", "seq", name="uq_messages_conversation_seq"),
    )

    op.create_table(
        "api_tokens",
        _id(),
        sa.Column("name", sa.String(100), nullable=False),
        sa.Column("token_hash", sa.String(64), nullable=False, unique=True),
        sa.Column("created_at", TS, nullable=False, server_default=sa.func.now()),
        sa.Column("last_used_at", TS),
        sa.Column("revoked_at", TS),
    )

    for table, expression in [
        ("items", "coalesce(title, '') || ' ' || coalesce(body, '')"),
        ("projects", "coalesce(name, '') || ' ' || coalesce(description, '')"),
        ("events", "coalesce(title, '') || ' ' || coalesce(notes, '') || ' ' || coalesce(location, '')"),
    ]:
        op.execute(
            f"ALTER TABLE {table} ADD COLUMN search_vector tsvector "
            f"GENERATED ALWAYS AS (to_tsvector('german', {expression})) STORED"
        )
        op.execute(f"CREATE INDEX ix_{table}_search ON {table} USING gin (search_vector)")


def downgrade() -> None:
    for table in ["api_tokens", "messages", "conversations", "events", "calendar_sources", "items", "projects", "areas"]:
        op.drop_table(table)
