"""Initial Hiwar schema."""

from alembic import op
import sqlalchemy as sa

revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.String(50), nullable=False, unique=True),
        sa.Column("name", sa.String(50), nullable=False),
        sa.Column("email", sa.String(100), unique=True),
        sa.Column("auth_provider", sa.String(30), nullable=False, server_default="manual"),
        sa.Column("auth_subject", sa.String(255)),
        sa.Column("age", sa.Integer()), sa.Column("education_level", sa.String(80)),
        sa.Column("certificates", sa.Text()), sa.Column("learning_reason", sa.Text()),
        sa.Column("daily_minutes", sa.Integer()), sa.Column("focus_skills", sa.Text()),
        sa.Column("profile_complete", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("password_hash", sa.String(255)), sa.Column("verification_code", sa.String(64)),
        sa.Column("verification_expires_at", sa.DateTime()),
        sa.Column("email_verified", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("level", sa.String(20), server_default="pending"),
        sa.Column("level_score", sa.Integer(), server_default="0"),
        sa.Column("total_sessions", sa.Integer(), server_default="0"),
        sa.Column("total_errors", sa.Integer(), server_default="0"),
        sa.Column("mastered_errors", sa.Integer(), server_default="0"),
        sa.Column("streak_days", sa.Integer(), server_default="0"),
        sa.Column("is_active", sa.Boolean(), server_default=sa.true()),
        sa.Column("created_at", sa.DateTime()), sa.Column("last_active", sa.DateTime()),
    )
    op.create_table(
        "conversations",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), nullable=False),
        sa.Column("is_active", sa.Integer(), nullable=False, server_default="1"),
    )
    op.create_table(
        "messages",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("conversation_id", sa.Integer(), sa.ForeignKey("conversations.id"), nullable=False),
        sa.Column("role", sa.Text(), nullable=False), sa.Column("content", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(), nullable=False),
    )
    op.create_table(
        "user_errors",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("error_type", sa.String(50)), sa.Column("wrong_text", sa.Text(), nullable=False),
        sa.Column("correct_text", sa.Text(), nullable=False), sa.Column("explanation", sa.Text()),
        sa.Column("context", sa.Text()), sa.Column("count", sa.Integer(), server_default="1"),
        sa.Column("mastered", sa.Boolean(), server_default=sa.false()),
        sa.Column("review_count", sa.Integer(), server_default="0"),
        sa.Column("first_occurrence", sa.DateTime()), sa.Column("last_occurrence", sa.DateTime()),
    )


def downgrade():
    op.drop_table("user_errors")
    op.drop_table("messages")
    op.drop_table("conversations")
    op.drop_table("users")
