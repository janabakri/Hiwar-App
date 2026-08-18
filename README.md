# HIWAR APP

AI-powered English learning platform with conversational AI, error tracking, and personalized learning.

## Features

-  Voice conversation with AI
-  Real-time error detection and correction
-  Personalized learning path
-  Progress tracking
-  Spaced repetition for errors
-  Multi-platform support

## Tech Stack

- **Backend**: FastAPI, Python
- **AI**: OpenAI GPT-4o-mini
- **Database**: PostgreSQL/SQLite
- **Voice**: ElevenLabs API (optional)
- **Deployment**: Docker, Docker Compose

## Quick Start


# Clone repository
git clone https://github.com/janabakri/HIWARApp.git
cd hiwarapp/backend

# Copy environment configuration
cp .env.example .env
# Edit .env with your API keys

# Install dependencies
pip install -r requirements.txt

# Run the application
uvicorn app.main:app --reload