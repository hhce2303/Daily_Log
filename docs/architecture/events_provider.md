# EventsProvider — Map-Based Local Event Staging

**Date:** 2025-04-11  
**Status:** Implemented  
**Scope:** Frontend — `daily-log-frontend/react-ts`

---

## Problem

Every time the user switched between tabs (Daily ↔ Covers, etc.), the page components unmounted and remounted, triggering fresh API calls to `GET /events/`, `GET /catalogs/sites/`, and `GET /catalogs/activities/`. In production this caused:

- Redundant network traffic on every tab switch.
- Visible loading flickers (spinner → data).
- Loss of any transient UI state.

## Solution

A React Context (`EventsProvider`) mounted **once at the App level** (above tab conditionals) that:

1. **Fetches backend data once** on mount and caches it in state.
2. **Provides a `Map<string, LocalEvent>`** for staging events locally before sending to the backend.
3. **Exposes a merged `allEvents` array** that combines local + backend events for table rendering.

## Architecture

```
App.tsx
└── AppContext.Provider
    └── EventsProvider          ← mounted once, survives tab switches
        ├── DailyPage           ← consumes useEvents()
        ├── CoversPage
        └── SupervisorPage ...
```

### Data Flow

```
User fills form → addLocal(payload)
                      │
                      ▼
              Map<string, LocalEvent>     ← key = crypto.randomUUID()
              status: "pending"
                      │
         User clicks "Enviar" → sendEvent(key)
                      │
                      ▼
              status: "sending"  (animate-pulse in UI)
                      │
              POST /events/
                      │
           ┌──────────┴──────────┐
       success                 failure
           │                      │
   move to backendEvents    status: "error"
   remove from Map          keep in Map
```

### LocalEvent Type

```ts
type LocalEventStatus = "pending" | "sending" | "error";

interface LocalEvent {
  key: string;                    // UUID
  payload: CreateEventPayload;    // original form data
  status: LocalEventStatus;
  error?: string;
  display: DailyEvent;            // snapshot for table rendering
}
```

## Files Modified

| File | Change |
|------|--------|
| `src/features/logs/EventsProvider.tsx` | **Created.** Context + Provider + `useEvents()` hook. |
| `src/App.tsx` | Wrapped tab views inside `<EventsProvider>`. |
| `src/pages/DailyPage.tsx` | Replaced `useDailyEvents()` + `useCatalogs()` with `useEvents()`. |
| `src/pages/Home.tsx` | Same pattern as DailyPage. |
| `src/features/logs/components/DailyEventForm.tsx` | `+` button adds to local Map (instant). `Enviar` button sends all pending. Removed `isSubmitting` prop. |
| `src/features/logs/components/DailyTable.tsx` | Accepts `localEvents` prop. Rows highlighted by status: yellow border (pending), cyan pulse (sending), red border (error). |
| `src/features/logs/columns.tsx` | `event_status` column renders color-coded badges. |

## Visual Indicators

### Status Column Badges
| Status | Style |
|--------|-------|
| `pending` | Yellow background, yellow text |
| `sending` | Cyan background, cyan text, `animate-pulse` |
| `error` | Red background, red text |
| (backend) | Blue background, blue text |

### Row Highlighting
| Status | Left Border | Background |
|--------|-------------|------------|
| `pending` | 4px yellow | `yellow-900/10` |
| `sending` | 4px cyan | `cyan-900/10` + `animate-pulse` |
| `error` | 4px red | `red-900/10` |
| (backend) | none | default |

## Context API

```ts
interface EventsContextValue {
  backendEvents: DailyEvent[];
  isLoading: boolean;
  fetchError: string | null;
  refetch: () => void;

  localEvents: Map<string, LocalEvent>;
  addLocal: (payload: CreateEventPayload) => void;
  sendEvent: (key: string) => Promise<void>;
  removeLocal: (key: string) => void;

  allEvents: DailyEvent[];         // merged: local displays + backend

  sites: SiteOption[];
  activities: ActivityOption[];     // deduplicated
  catalogsLoading: boolean;
}
```

## Key Decisions

- **Map over Array** — O(1) lookups by UUID key; clean add/remove/update semantics.
- **Negative temp IDs** (`-Date.now()`) for local events — avoids collision with backend numeric IDs and enables row-level identification without extra props.
- **Catalog deduplication** — `activities` are deduplicated by `id` using a `Set<number>` because the backend returns duplicates from `daily_activities`.
- **`useDailyEvents` / `useCatalogs` hooks preserved** — still in `hooks.ts` but no longer used by pages. Kept for potential reuse in isolated contexts.
