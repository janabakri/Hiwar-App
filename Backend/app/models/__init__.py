"""Models package for database tables."""

# Importing the models here guarantees that SQLAlchemy registers every table
# before ``Base.metadata.create_all`` runs in app.main.
from .conversation import ConversationTurn  # noqa: F401
from .error import UserError  # noqa: F401
from .learning import (  # noqa: F401
    AIUsageEvent,
    AgentTrace,
    LearningEvent,
    LearningItem,
    ReadingAttempt,
    ReadingMaterial,
    SpeakingAttempt,
    SpeakingTurn,
    TutorSession,
)
from .user import User  # noqa: F401
