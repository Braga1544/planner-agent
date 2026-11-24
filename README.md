# planner-agent

Self-hosted planning assistant: calendar, todos, projects, ideas and notes in one place, with a Claude agent that can read and change all of it through tools.

One backend, two clients:

| Part | Stack |
| --- | --- |
| API + agent | FastAPI, PostgreSQL, SQLAlchemy (async), Alembic, Anthropic SDK |
| Web app | React 19, TanStack Query, Tailwind, Vitest |
| iOS app | SwiftUI (iOS 17+), dictation, local reminders |

## How the agent works

The chat runs a tool-use loop against the Anthropic API (streaming, adaptive thinking, prompt caching). The agent gets 14 tools that operate on the same data as the REST API: `get_agenda`, `list_events`, `search`, `create_item`, `update_event` and so on. Tool inputs are Pydantic models, so the JSON schemas the model sees and the validation that runs are the same thing.

Details worth knowing:

- Every stored `tool_use` gets a `tool_result`, even when a run is cancelled mid-turn. A conversation with a dangling `tool_use` is rejected by the API, so the loop also repairs that state on the next request.
- The agent run is decoupled from the HTTP stream. If the client disconnects, the run finishes and the history stays complete.
- The system prompt contains nothing time-dependent, so it stays a stable cache prefix. The current time is injected per message instead.
- All times are handled in local time (Europe/Berlin) at the edges, including recurring events across DST changes.

## Features

- Events with recurrence rules (RRULE), reminders and all-day handling
- Todos, ideas and notes, optionally grouped into projects
- ICS import from external calendars (Outlook, iCloud, …), synced on a schedule
- ICS feed export, so the calendar can be subscribed to from any client
- Full-text search across everything (Postgres `websearch_to_tsquery`)
- Chat streamed via SSE to web and iOS
- Token-based auth per device

## Running locally

```bash
cp .env.example .env            # set ANTHROPIC_API_KEY and ICS_FEED_TOKEN
docker compose up -d db
uv sync
uv run alembic upgrade head
uv run python -m app.cli create-token "dev"
uv run uvicorn app.main:app --reload
```

API docs: http://localhost:8000/docs

Web app:

```bash
cd web
npm ci
npm run dev
```

iOS app: see [ios/README.md](ios/README.md).

## Tests

```bash
uv run pytest                 # backend, needs Docker for Postgres (testcontainers)
uv run pytest -m live         # a few real Claude calls, needs an API key
cd web && npm test            # web
```

On Docker Desktop (Windows/macOS) the testcontainers cleanup container can fail to bind its port. `TESTCONTAINERS_RYUK_DISABLED=true uv run pytest` works around it.

## Making it yours

This was built for one person, so a few things are hardcoded to that setup. If you run it yourself, these are the places to touch:

| What | Default | Where |
| --- | --- | --- |
| Areas (top-level buckets) | `work`, `business`, `hobby`, `personal` | `app/schemas/common.py`, seed in `alembic/versions/0001_initial.py`, `app/agent/prompt.py`, `web/src/lib/types.ts` + icons in `web/src/components/Layout.tsx`, `ios/Planer/Domain/Models.swift` |
| Timezone | Europe/Berlin | `TIMEZONE` in `.env` for the backend; web (`web/src/lib/time.ts`) and iOS (`ios/Planer/Domain/BerlinTime.swift`) have it hardcoded |
| Language | German (UI, system prompt, tool descriptions, error messages) | `app/agent/prompt.py`, `app/agent/tools.py`, the clients' strings |
| URL paths | German (`/kalender`, `/bereiche/:area`, `/projekte/:id`, `/suche`, `/einstellungen`) | `web/src/routes.tsx`, links in the pages, SPA test in `tests/test_spa.py` |
| Date and time format | `de-DE` | `Intl.DateTimeFormat` in `web/src/lib/time.ts` and `web/src/pages/CalendarPage.tsx`, `BerlinTime.swift` and the speech recognizer (`SpeechRecognizer.swift`) on iOS |
| Model | `claude-sonnet-5-5`, effort `medium` | `CLAUDE_MODEL` / `CLAUDE_EFFORT` in `.env` |
| Exposure | Cloudflare Tunnel + Access | `docker-compose.prod.yml`, [docs/deployment.md](docs/deployment.md); any reverse proxy with auth works too |

The areas are the only change that touches every layer. Rename them everywhere in one go and add a migration for existing data.

## Deployment

`docker-compose.prod.yml` runs Postgres, the app (API and web on one port), a Cloudflare Tunnel and a daily `pg_dump` backup. The app is only reachable through Cloudflare Access from outside. Details in [docs/deployment.md](docs/deployment.md).

Run exactly one instance: the scheduler and the per-chat lock live in-process.

## License

MIT
