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
- **Rate Limiting**: slowapi (with Redis backend for distributed deployments)
- **Testing**: pytest
- **Linting**: black, flake8, isort

## Rate Limiting

All authentication endpoints are rate-limited to prevent abuse:

| Endpoint | Rate Limit | Scope | Purpose |
|----------|------------|-------|---------|
| `POST /v1/auth/signup` | 5 requests/hour | Per IP | Prevent spam account creation |
| `POST /v1/auth/signin` | 10 requests/minute | Per IP | Prevent brute force attacks while allowing retries |
| `POST /v1/auth/reset-password` | 3 requests/hour | Per IP | Prevent email bombing |

**Response on rate limit exceeded:**
- HTTP Status: `429 Too Many Requests`
- Body: Plain text error message (e.g., "429: Too Many Requests")
- Note: Response format may be enhanced in future to include structured JSON with retry timing

**Client handling recommendations:**
- Implement exponential backoff on 429 responses
- Show user-friendly message: "Too many attempts. Please try again in X minutes."
- Don't retry immediately on 429
- Assume 60-second default retry window if response doesn't specify timing

**Production deployment:**

Set `REDIS_URL` environment variable for distributed rate limiting:
```bash
# Development (local)
REDIS_URL=memory://

# Production (with Redis)
REDIS_URL=redis://your-redis-host:6379
```

Without Redis, rate limits only apply per-instance. In distributed deployments (Kubernetes, multiple servers), use Redis to share rate limit state across all instances.

## API Documentation

Once running, API docs available at:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Status

⚠️ **This is a scaffold** - Backend implementation is planned but not yet started.

See [API.md](../API.md) for planned endpoints and contracts.
