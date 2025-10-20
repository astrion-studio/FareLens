# FareLens Backend API

FastAPI backend for FareLens flight deal tracking app.

## Structure

```
backend/
├── app/
│   ├── api/          # API routes and endpoints
│   ├── core/         # Core configuration (settings, security)
│   ├── models/       # Database models
│   ├── services/     # Business logic services
│   └── main.py       # FastAPI application entry point
├── tests/            # Unit and integration tests
├── requirements.txt  # Python dependencies
└── Dockerfile        # Container configuration
```

## Setup (Planned)

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run development server
uvicorn app.main:app --reload
```

## Technology Stack

- **Framework**: FastAPI
- **Database**: PostgreSQL
- **Cache**: Redis
- **Authentication**: JWT
- **Testing**: pytest
- **Linting**: black, flake8, isort

## API Documentation

Once running, API docs available at:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Status

⚠️ **This is a scaffold** - Backend implementation is planned but not yet started.

See [API.md](../API.md) for planned endpoints and contracts.
