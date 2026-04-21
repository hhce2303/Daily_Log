# Daily Events — Frontend Implementation Report

**Date:** 2025-07-11  
**Scope:** Frontend only (`daily-log-frontend/react-ts/src/features/logs/`)  
**Status:** Implemented — **awaiting backend endpoints**

---

## ⚠️ IMPORTANT: Backend Dependency

This implementation **cannot be tested** until the corresponding backend endpoints are created.

The frontend is fully wired to call real API endpoints via the shared HTTP client (`lib/api/client.ts`), but those endpoints **do not exist yet** on the Django REST API.

The implementation is designed to be **flexible**: if the backend response shape changes slightly, only `types.ts` and `api.ts` need to be updated — hooks, columns, and form remain stable.

---

## Endpoints Expected (Frontend → Backend Contract)

### 1. `GET /api/v1/events/`

Fetch shift events for the authenticated user. Backend should filter from the last START SHIFT (activity_id = 44) automatically based on the JWT token.

**Response:**
```json
{
  "data": [
    {
      "id": 1,
      "site_name": "AS Koons Test",
      "activity_name": "Cleaner In",
      "event_datetime": "2025-07-11T08:30:00Z",
      "event_status": "confirmed",
      "quantity": 3,
      "camera": "CAM-01",
      "description": "North entrance"
    }
  ],
  "total": 1
}
```

### 2. `POST /api/v1/events/`

Create a new daily event. Backend resolves: user (from JWT), `event_datetime` (server-side `now()`), `event_status`.

**Request:**
```json
{
  "site_id": 5,
  "activity_id": 12,
  "quantity": 2,
  "camera": "CAM-01",
  "description": "Optional note"
}
```

**Response:** The created `DailyEvent` object (same shape as items in GET response).

### 3. `GET /api/v1/catalogs/sites/`

All available sites for the dropdown.

**Response:**
```json
[
  { "id": 1, "site_name": "AS Koons Test" },
  { "id": 2, "site_name": "Site B" }
]
```

### 4. `GET /api/v1/catalogs/activities/`

All available activities for the dropdown.

**Response:**
```json
[
  { "id": 1, "act_name": "Cleaner In" },
  { "id": 2, "act_name": "Cleaner Out" }
]
```

---

## Files Modified

| File | Change |
|------|--------|
| `features/logs/types.ts` | Replaced mock types with API contract types (`DailyEvent`, `CreateEventPayload`, `SiteOption`, `ActivityOption`) |
| `features/logs/api.ts` | Replaced mock functions with real API calls (`fetchShiftEvents`, `createEvent`, `fetchSites`, `fetchActivities`) |
| `features/logs/hooks.ts` | Rewrote `useDailyEvents` (no pagination params, auto-fetch, `addEvent` + `refetch`). Added `useCatalogs` hook |
| `features/logs/columns.tsx` | Updated column accessors to match new field names (`event_datetime`, `site_name`, `activity_name`, `event_status`, `quantity`, `camera`, `description`) |
| `features/logs/components/DailyEventForm.tsx` | Removed hardcoded catalogs and date field. Now receives `sites`/`activities` via props, sends `site_id`/`activity_id` numbers |
| `features/logs/index.ts` | Removed `mockData` export |
| `pages/DailyPage.tsx` | Replaced `useState(mockDailyEvents)` with `useDailyEvents()` + `useCatalogs()` hooks |
| `pages/Home.tsx` | Same change as DailyPage (was a duplicate) |

---

## Architecture Decisions

1. **No date field in form** — Backend sets `event_datetime` server-side with `now()` on creation.
2. **IDs instead of strings** — Form sends `site_id`/`activity_id` (numbers), not names. Backend resolves names for GET responses.
3. **No frontend processing** — The frontend sends raw payload, waits for 200 or shows the error. No `pending_changes`, no `event_converter_to_special` hooks on the client.
4. **START SHIFT filter is server-side** — `GET /events/` doesn't pass any shift parameters. Backend handles the range filter based on the authenticated user's last START SHIFT session.
5. **Catalogs loaded once on mount** — `useCatalogs` fetches sites and activities when the form mounts and caches in state.

---

## What Needs to Happen Next (Backend)

1. Create `GET /api/v1/events/` endpoint with START SHIFT filter logic
2. Create `POST /api/v1/events/` endpoint that resolves user from JWT, sets datetime and status
3. Create `GET /api/v1/catalogs/sites/` endpoint (read from `daily_sites` table)
4. Create `GET /api/v1/catalogs/activities/` endpoint (read from `daily_activities` table)
5. Wire URL routes in `config/urls.py` or a new `apps/events/urls.py`
