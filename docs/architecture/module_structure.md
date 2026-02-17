# Module Structure

## Frontend Architecture (Feature-Based Modular Monolith)

El frontend de Daily Log sigue una arquitectura **feature-based** donde cada feature es un módulo independiente con su propia lógica, tipos, y componentes. Esta estructura facilita el mantenimiento, testeo, y escalabilidad del código.

---

## Core Principles

1. **Separation of Concerns:** Cada feature tiene su propia carpeta con tipos, lógica, y UI separados
2. **Single Responsibility:** Componentes presentacionales (solo UI) vs container components (lógica + state)
3. **Barrel Exports:** Cada feature expone un `index.ts` con exports centralizados
4. **Type Safety:** TypeScript strict mode, interfaces completas para props y domain models
5. **Reusability:** Components shared van en `/shared/components`, feature-specific en `/features/[feature]/components`

---

## Directory Structure

```
src/
│
├── features/                    # Feature modules (domain-driven)
│   ├── auth/                    # Authentication feature
│   ├── logs/                    # Daily Events logs feature
│   ├── covers/                  # Cover requests feature
│   └── specials/                # Special events feature (supervisor)
│
├── pages/                       # Page components (routing endpoints)
│   ├── DailyPage.tsx
│   ├── CoversPage.tsx
│   ├── SupervisorPage.tsx
│   └── SpecialsPage.tsx
│
├── layouts/                     # Layout components
│   └── MainLayout.tsx
│
├── shared/                      # Shared/common code
│   └── components/              # Reusable UI components
│       ├── DotGrid/
│       ├── PillNav/
│       ├── Topbar.tsx
│       ├── Sidebar.tsx
│       └── MagicBento/
│
├── App.tsx                      # Root component + routing logic
└── main.tsx                     # Entry point
```

---

## Feature Modules

### 1. `features/auth/` - Authentication

**Purpose:** Maneja autenticación de usuarios (login/logout), definición de roles, y user state.

**Structure:**
```
features/auth/
├── types.ts                     # User, UserRole interfaces
├── api.ts                       # Mock auth functions (LOGIN, MOCK_USERS)
├── components/
│   ├── Login.tsx                # Login form component
│   └── InputField.tsx           # Reusable input component
└── index.ts                     # Barrel exports
```

**Key Types:**
- `UserRole`: "operador" | "supervisor" | "lead_supervisor" | "admin"
- `User`: { username, displayName, role }

**Current Implementation:**
- Hardcoded users con TODO comments (ADR-006)
- MOCK_USERS: `operador/1234`, `supervisor/4321`
- LOGIN function simula autenticación (no backend)

**Future:**
- Backend integration con LDAP (ADR-003)
- JWT tokens
- Session management

**Related ADRs:** ADR-003 (Login Flow), ADR-006 (Role-Based Auth)

---

### 2. `features/logs/` - Daily Events Logs

**Purpose:** Gestión de eventos diarios reportados por Operadores (rol operador).

**Structure:**
```
features/logs/
├── types.ts                     # DailyEvent interface
├── mockData.ts                  # Mock daily events (TODO: DELETE)
├── columns.tsx                  # TanStack Table column definitions
├── components/
│   ├── DailyEventTable.tsx      # Table presentational component
│   └── DailyEventForm.tsx       # Form for creating new events
└── index.ts                     # Barrel exports
```

**Key Types:**
- `DailyEvent`: { id, date, time, site, activity, quantity, camera, description, user, timezone }

**Components:**
- `DailyEventTable`: TanStack Table con sorting y pagination
- `DailyEventForm`: Form para agregar nuevos eventos

**Current Implementation:**
- Mock data hardcoded
- Local state management (useState)
- Client-side pagination y sorting

**Future:**
- Backend API integration
- Real-time updates
- Advanced filtering

**Related ADRs:** ADR-004 (TanStack Table)

---

### 3. `features/covers/` - Cover Requests

**Purpose:** Gestión de solicitudes de cobertura (breaks, lunches) por Operadores.

**Structure:**
```
features/covers/
├── types.ts                     # CoverRequest interface
├── mockData.ts                  # Mock cover requests (TODO: DELETE)
├── columns.tsx                  # TanStack Table column definitions
├── components/
│   ├── CoversTable.tsx          # Table presentational component
│   └── CoverForm.tsx            # Form for requesting covers
└── index.ts                     # Barrel exports
```

**Key Types:**
- `CoverRequest`: { id, date, time, type, duration, reason, requestedBy, status }

**Components:**
- `CoversTable`: TanStack Table con sorting y pagination
- `CoverForm`: Form para solicitar covers

**Current Implementation:**
- Mock data hardcoded
- Local state management
- Status: "pending" | "approved" | "rejected"

**Future:**
- Supervisor approval workflow
- Push notifications
- Calendar integration

**Related ADRs:** ADR-004 (TanStack Table)

---

### 4. `features/specials/` - Special Events (Supervisor)

**Purpose:** Gestión de eventos especiales reportados por Operadores, revisados por Supervisores. Eventos críticos que requieren aprobación y seguimiento.

**Structure:**
```
features/specials/
├── types.ts                     # SpecialEvent, SpecialsFilters interfaces
├── mockData.ts                  # Mock special events (TODO: DELETE)
├── columns.tsx                  # TanStack Table column definitions
├── components/
│   └── SpecialsTable.tsx        # Table presentational component
└── index.ts                     # Barrel exports
```

**Key Types:**
```typescript
interface SpecialEvent {
  id: string;                    // UUID del evento especial
  eventId: string;               // FK a Daily Event (parent)
  status: "pendiente" | "enviado" | "revisado";
  priority: "low" | "medium" | "high" | "critical";
  assignedTo: string;            // Supervisor username
  dateReported: Date;
  timeReported: string;          // HH:MM format
  site: string;
  activity: string;
  description: string;           // Descripción extendida
  reportedBy: string;            // Operador username
  timezone: string;              // e.g., "GMT-4"
}
```

**Components:**
- `SpecialsTable`: TanStack Table con sorting, pagination, conditional styling
  - Props: `data`, `isLoading`, `error`, `pagination`, `onPaginationChange`
  - States: loading, error, empty
  - Features: Status badges (yellow/blue/green), Priority badges (blue/yellow/orange/red)

**Columns (9):**
1. **Fecha** - Date reportada (es-ES locale)
2. **Hora** - Time reportada (HH:MM)
3. **Sitio** - Location del evento
4. **Actividad** - Activity type
5. **Descripción** - Descripción truncada con tooltip
6. **Reportado Por** - Operador username (capitalized, colored)
7. **Prioridad** - Priority badge con color coding
8. **Estado** - Status badge (pendiente/enviado/revisado)
9. **Asignado A** - Supervisor username (capitalized, colored)

**Mock Data (5 events):**
- Security incidents: 2 (unauthorized access, equipment tampering)
- Equipment failures: 1 (CCTV camera malfunction)
- System alerts: 1 (power outage)
- Visitor issues: 1 (VIP guest arrival)

**Status Distribution:**
- Pendiente: 1 (requires immediate attention)
- Enviado: 1 (submitted for review)
- Revisado: 3 (completed review)

**Priority Distribution:**
- Critical: 2 (security incidents, power outage)
- High: 1 (equipment failure)
- Medium: 1 (system alert)
- Low: 1 (visitor issue)

**Current Implementation:**
- Mock data hardcoded con TODO comments
- Read-only approval queue (NO FORM component)
- Local state management en SpecialsPage
- Client-side sorting y pagination
- Conditional styling por status y priority

**Architectural Differences vs Daily/Covers:**

| Aspecto              | Daily/Covers          | **Specials**           |
|----------------------|-----------------------|------------------------|
| **User Role**        | Operador              | **Supervisor**         |
| **Form Component**   | ✅ Form para crear    | ❌ **NO FORM**         |
| **Primary Action**   | Create new entries    | **Review & Approve**   |
| **Data Source**      | User input            | **Promoted from Daily Events** |
| **Workflow**         | Simple CRUD           | **3-state workflow**   |
| **FK Relationship**  | None                  | **eventId → DailyEvent** |

**Why NO FORM?**
- Special events son **promovidos de Daily Events** por Operadores
- Supervisores **revisan y aprueban**, no crean
- Futuro: Actions (Approve, Reject, Reassign, Add Notes) no requieren form tradicional

**Future Features (Roadmap):**
1. **Backend Integration** - API calls (GET, PUT status updates)
2. **Supervisor Actions** - Approve, Reject, Reassign, Add Notes
3. **Advanced Filtering** - Por status, priority, site, date range, assignee
4. **Export Functionality** - PDF, Excel (requerido por legacy system)
5. **Real-time Notifications** - Badge counts, toast notifications, browser notifications
6. **Email Escalation** - Critical priority events auto-notifican

**Legacy System Compliance:**
Basado en `legacy_desktop_functional_context.md` sección 3.3:
- ✅ Special events based on Daily Events (eventId FK)
- ✅ Status tracking: pendiente/enviado/revisado
- ✅ Supervisor assignment: assignedTo field
- ✅ Priority levels: low/medium/high/critical
- ✅ Timezone handling
- ✅ Full metadata
- ⏳ Approval workflow: UI lista, lógica pendiente
- ⏳ Reassignment: Estructura lista, UI pendiente
- ⏳ Notes/Comments: Estructura lista, UI pendiente

**Related ADRs:** 
- ADR-004 (TanStack Table)
- ADR-006 (Role-Based Auth)
- ADR-008 (Specials Events Feature)

**Related Files:**
- `pages/SpecialsPage.tsx` - Page container con stats summary y table
- `App.tsx` - Routing integration (AppView includes "specials")
- `Topbar.tsx` - Nav item "Specials" para supervisor role
- `SupervisorPage.tsx` - Dashboard card navigation onClick

---

### 5. `features/audit/` - Audit Trail (Supervisor)

**Purpose:** Vista de auditoría para Supervisores que muestra **todos los eventos de operadores** con capacidades de filtrado avanzado. Read-only view para compliance, supervisión, y revisión de actividades.

**Structure:**
```
features/audit/
├── types.ts                     # AuditEvent, AuditFilters interfaces
├── mockData.ts                  # Mock audit events (TODO: DELETE)
├── columns.tsx                  # TanStack Table column definitions (8 columns)
├── components/
│   ├── AuditTable.tsx           # Table presentational component
│   └── AuditFilters.tsx         # Filter component (Usuario, Sitio, Fecha)
└── index.ts                     # Barrel exports
```

**Key Types:**
```typescript
interface AuditEvent {
  id: string;                    // Event ID (legacy: ID_Evento)
  date: Date;                    // Date del evento
  time: string;                  // HH:MM:SS format
  site: string;                  // Nombre_Sitio (location)
  activity: string;              // Nombre_Actividad (activity type)
  quantity: number;              // Cantidad de unidades
  camera: string;                // Camera ID
  description: string;           // Descripción del evento
  user: string;                  // Operador username (critical for filtering)
  timezone: string;              // e.g., "GMT-4"
}

interface AuditFilters {
  user?: string;                 // Operator username filter
  site?: string;                 // Site location filter
  dateFrom?: Date;               // Date range start
  dateTo?: Date;                 // Date range end (future)
}
```

**Components:**

1. **`AuditTable`:** TanStack Table con sorting, pagination, 3 estados
   - **Props:** `data`, `isLoading`, `error`, `pagination`, `onPaginationChange`
   - **States:** 
     * Loading: "Cargando eventos de auditoría..."
     * Error: Error message display
     * Empty: "No se encontraron eventos. Intenta ajustar los filtros."
   - **Features:**
     * Sorting state managed internally
     * 5-button pagination: <<, <, Page X of Y, >, >>
     * Display: "Mostrando X a Y de Z eventos"
   - **Design:** Clean table design matching SpecialsTable (ADR-008)
     * bg-slate-800/50 container
     * bg-slate-700/50 headers
     * divide-slate-700/50 row dividers
     * slate-600 borders

2. **`AuditFilters`:** Filter search component con 3 campos + 2 botones
   - **Props:** `onFilter`, `onClear`
   - **Local State:** filters object managed with useState
   - **Filter Fields:**
     * **Usuario:** Text input (TODO: replace with dropdown when backend ready)
     * **Sitio:** Text input (TODO: replace with dropdown when backend ready)
     * **Fecha (Desde):** Date picker (input[type="date"])
   - **Action Buttons:**
     * **Buscar:** Blue bg-sigBlue button with 🔍 icon (triggers onFilter)
     * **Limpiar:** Gray bg-slate-700/50 button (triggers onClear)
   - **Layout:** Grid md:grid-cols-4 (3 filters + buttons column)
   - **Future:** Date range picker (Fecha Hasta) - handleDateToChange commented out

**Columns (8):**
1. **ID Evento** - Event ID (font-mono, gray text, compact)
2. **Fecha Hora** - Combined display column (date + time, es-ES locale)
3. **Nombre Sitio** - Location (truncated max-w-xs, tooltip on hover)
4. **Nombre Actividad** - Activity type
5. **Cantidad** - Quantity (centered display)
6. **Camara** - Camera ID (centered, shows "-" if empty)
7. **Descripción** - Description (truncated max-w-md, tooltip on hover)
8. **Usuario** - Operator username (gray text styling)

**Mock Data (21 events):**
- **Time Range:** Feb 15, 2026, 12:11:12 - 12:44:12 (33-minute window)
- **Operators (10+):** Logan OP, Emanuel B, Juan C Perez, Carolina N, Vladimir P, Nicolas C, Daniela B, Jaime A, Maria Paula L, Aramis M, Alejanra Ramir, Katherine Tavar, Ruben T
- **Sites (15+):** HUD Paint and Body Centre, ML Volvo Collision Corp, AS Park Place Sprinter Van Center, AS Plaza Audi-BMW-Infiniti-MB-Lot, ML Joe Machens, AS Koons, ML Gray Daniels, Luther Brookdale, Ken Garff, AS Bill Estes, AS Stevinson, ML Nissan, AS David McDavid, AS Nalley, etc.
- **Activities (12+):** Detailer out/in/on site, Pickup, Cleaner in/on site, Switch Car, Dropoff, Employee in/out/on site, Security Patroling, etc.
- **Scenarios:** Realistic operator activity scenarios across multiple locations

**Current Implementation:**
- Mock data hardcoded con TODO comments ("DELETE WHEN BACKEND IS READY")
- Read-only audit trail (NO FORM component)
- Client-side filtering logic con useMemo optimization
- Automatic pagination reset on filter change
- Results summary displays active filters and event count

**Filtering Logic (Client-Side - Temporary):**
```typescript
const filteredEvents = useMemo(() => {
  let filtered = [...events];
  
  // User filter: case-insensitive partial match
  if (activeFilters.user) {
    filtered = filtered.filter((event) =>
      event.user.toLowerCase().includes(activeFilters.user!.toLowerCase())
    );
  }
  
  // Site filter: case-insensitive partial match
  if (activeFilters.site) {
    filtered = filtered.filter((event) =>
      event.site.toLowerCase().includes(activeFilters.site!.toLowerCase())
    );
  }
  
  // Date filter: events >= dateFrom (normalized to midnight)
  if (activeFilters.dateFrom) {
    filtered = filtered.filter((event) => {
      const eventDate = new Date(event.date);
      eventDate.setHours(0, 0, 0, 0);
      const fromDate = new Date(activeFilters.dateFrom!);
      fromDate.setHours(0, 0, 0, 0);
      return eventDate >= fromDate;
    });
  }
  
  return filtered;
}, [events, activeFilters]);
```

**Architectural Differences vs Daily/Covers/Specials:**

| Aspecto              | Daily/Covers          | Specials              | **Audit**                |
|----------------------|-----------------------|-----------------------|--------------------------|
| **User Role**        | Operador              | Supervisor            | **Supervisor**           |
| **Form Component**   | ✅ Create entries     | ❌ NO FORM            | ❌ **NO FORM**           |
| **Filter Component** | ❌ No filters         | ❌ No filters         | ✅ **SÍ (3 campos)**     |
| **Primary Action**   | Add events            | Review & Approve      | **Search & Filter**      |
| **Data Scope**       | Single user           | Single user events    | **Multi-user events**    |
| **Data Source**      | User creates          | Promoted from Daily   | **All Daily Events**     |
| **Purpose**          | Operational log       | Escalation queue      | **Compliance audit**     |
| **Columns**          | 7 columns             | 9 columns             | **8 columns**            |

**Why NO FORM?**
- Audit es **view-only** de eventos existentes
- Eventos son **creados por operadores** en Daily module
- Propósito es **supervisión y compliance**, no creación
- Supervisores solo **buscan, filtran, y revisan** eventos

**Why SÍ FILTERS?**
- Legacy UI muestra **3 campos de búsqueda** (Usuario, Sitio, Fecha)
- Necesario para **navegar gran volumen** de eventos cross-user
- Sin filtros, tabla con 100+ eventos sería imposible de usar
- **Diferenciador clave** vs Daily Events (single user no necesita filtros)

**Future Features (Roadmap):**
1. **Backend Integration** - Replace mockAuditEvents with `useAuditEvents(filters, pagination)` hook
   - API call: GET /api/audit/events?user=X&site=Y&dateFrom=Z
   - Server-side filtering y pagination
   - Real-time updates (opcional)

2. **Advanced Filtering** - Enhanced search capabilities
   - Replace text inputs con dropdowns (user list, site list from backend)
   - Date range picker (dateFrom/dateTo) instead of single date
   - Multi-select filters (multiple users, multiple sites)
   - Activity type filter
   - Save filter presets

3. **Export Functionality** - Reports generation
   - Export to PDF (requerido por legacy system)
   - Export to Excel (optional)
   - Email reports (scheduled audits)
   - Custom report builder

4. **Statistics Dashboard** - Analytics view
   - Activity by operator (charts)
   - Events by site (charts)
   - Peak activity times (heatmap)
   - Compliance metrics (event count trends)

5. **Search Optimization** - Performance improvements
   - Full-text search en description
   - Search history (recent searches)
   - Quick filters (today, this week, this month)
   - Advanced query builder

**Legacy System Compliance:**
Basado en `legacy_desktop_functional_context.md` sección 3.7:
- ✅ Admin Dashboard with audit responsibilities
- ✅ Tracks all operator events across the system
- ✅ Filter by user (Usuario)
- ✅ Filter by site (Sitio)
- ✅ Filter by date (Fecha)
- ✅ Read-only view (no creation/editing)
- ✅ Cross-user event visibility
- ⏳ Export functionality: Pendiente (PDF, Excel)
- ⏳ Advanced statistics: Pendiente (activity by operator)

**Performance Considerations:**
- **Client-side filtering:** O(n) per filter (acceptable para <1000 eventos)
- **useMemo optimization:** Re-filters only when events or activeFilters change
- **Pagination default:** 10 items per page (adjustable)
- **Future:** Server-side filtering required para >1000 eventos
- **Future:** Virtual scrolling si table rows >100

**Related ADRs:** 
- ADR-004 (TanStack Table)
- ADR-006 (Role-Based Auth)
- ADR-008 (Specials Events Feature - clean table design pattern)
- ADR-009 (Audit Trail Feature)

**Related Files:**
- `pages/AuditPage.tsx` - Page container con filters + results summary + table
- `App.tsx` - Routing integration (AppView includes "audit")
- `Topbar.tsx` - Nav item "Audit" para supervisor role
- `SupervisorPage.tsx` - Dashboard 4th card navigation onClick (violet glow)

---

### 6. `features/coverTime/` - Cover Time Audit (Supervisor)

**Purpose:** Vista de auditoría de tiempo de covers completados para Supervisores. Permite revisar historial de covers, monitoreando tiempo que operadores estuvieron cubiertos por otros durante breaks, baños, emergencias, etc.

**Structure:**
```
features/coverTime/
├── types.ts                     # CoverTimeEvent, CoverTimeFilters interfaces
├── mockData.ts                  # Mock completed covers (TODO: DELETE)
├── columns.tsx                  # TanStack Table column definitions (7 columns)
├── components/
│   ├── CoverTimeTable.tsx       # Table presentational component
│   └── CoverTimeFilters.tsx     # Filter component (Usuario, Desde, Hasta)
└── index.ts                     # Barrel exports
```

**Key Types:**
```typescript
interface CoverTimeEvent {
  id: string;                    # UUID del cover event
  user: string;                  # Operador cubierto (username)
  startTime: Date;               # Inicio Cover (timestamp)
  duration: string;              # Duración HH:MM:SS format
  endTime: Date;                 # Fin Cover (timestamp)
  coveredBy: string;             # Operador que cubrió (username)
  reason: string;                # Motivo: Break, Cover Baño, Emergencia, etc.
  timezone: string;              # e.g., "GMT-4"
}

interface CoverTimeFilters {
  user?: string;                 # Filtrar por operador cubierto
  dateFrom?: Date;               # Rango fecha inicio (Desde)
  dateTo?: Date;                 # Rango fecha fin (Hasta)
}
```

**Components:**

1. **`CoverTimeTable`:** TanStack Table con sorting, pagination, 3 estados
   - **Props:** `data`, `isLoading`, `error`, `pagination`, `onPaginationChange`
   - **States:** 
     * Loading: "Cargando covers completados..."
     * Error: Error message display
     * Empty: "No se encontraron covers completados..."
   - **Features:**
     * Sorting state managed internally
     * 5-button pagination: <<, <, Page X of Y, >, >>
     * Display: "Mostrando X a Y de Z covers"
   - **Design:** Clean table design matching SpecialsTable, AuditTable (ADR-008, ADR-009)
     * bg-slate-800/50 container
     * bg-slate-700/50 headers
     * divide-slate-700/50 row dividers
     * slate-600 borders

2. **`CoverTimeFilters`:** Filter search component con 3 campos + 2 botones
   - **Props:** `onFilter`, `onClear`
   - **Local State:** filters object managed with useState
   - **Filter Fields:**
     * **Usuario:** Text input (TODO: replace with dropdown when backend ready)
     * **Desde:** Date picker (input[type="date"])
     * **Hasta:** Date picker (input[type="date"])
   - **Action Buttons:**
     * **Filtrar:** Blue bg-sigBlue button with 🔍 icon (triggers onFilter)
     * **Limpiar:** Gray bg-slate-700/50 button (triggers onClear)
   - **Layout:** Grid md:grid-cols-4 (3 filters + buttons column)

**Columns (7):**
1. **#** - Row number (display column, slate-400 monospace, compact)
2. **Usuario** - Operator who was covered (capitalized, medium font)
3. **Inicio Cover** - Start time (date + time, es-ES locale)
4. **Duración** - Duration (HH:MM:SS monospace, centered)
5. **Fin Cover** - End time (date + time, es-ES locale)
6. **Cubierto por** - Who covered (capitalized)
7. **Motivo** - Reason (badge with color coding)

**Color Coding for Reason:**
- **Emergencia:** Red badge (bg-red-500/20 text-red-300) - High priority visual
- **Lunch:** Green badge (bg-green-500/20 text-green-300) - Normal, expected
- **Baño:** Yellow badge (bg-yellow-500/20 text-yellow-300) - Short, expected
- **Break:** Blue badge (bg-blue-500/20 text-blue-300) - Normal

**Mock Data (20 covers):**
- **Operators (10+):** Andres G, Logan OP, Emanuel B, Juan C Perez, Carolina N, Vladimir P, Nicolas C, Daniela B, Jaime A, Maria Paula L, Aramis M
- **Cover Providers (10+):** Elizabeth C, Alejandra O, Kevin Castro, Emanuel B, Carolina N, Vladimir P, Maria Paula L, Aramis M, Nicolas C, Daniela B, Juan C Perez, Jaime A, Logan OP, Ruben T, Katherine Tavar, Alejanra Ramir
- **Reasons (5 types):** Break, Cover Baño, Lunch Break, Emergencia Personal, Emergencia Médica
- **Duration Range:** 00:05:30 (baño corto) to 00:47:55 (break largo/emergencia)
- **Date:** Feb 15, 2026 (consistent con Audit mock data)
- **Realistic Mix:** Mayoría breaks y baños (normal), pocas emergencias (anormal)

**Current Implementation:**
- Mock data hardcoded con TODO comments ("DELETE WHEN BACKEND IS READY")
- Read-only audit view (NO FORM component)
- Client-side filtering logic con useMemo optimization
- Date range filtering (Desde/Hasta) vs Audit single date
- Automatic pagination reset on filter change
- Results summary displays active filters and cover count

**Filtering Logic (Client-Side - Temporary):**
```typescript
const filteredEvents = useMemo(() => {
  let filtered = [...events];
  
  // User filter: case-insensitive partial match
  if (activeFilters.user) {
    filtered = filtered.filter((event) =>
      event.user.toLowerCase().includes(activeFilters.user!.toLowerCase())
    );
  }
  
  // Date range filter: events >= dateFrom (normalized to midnight)
  if (activeFilters.dateFrom) {
    filtered = filtered.filter((event) => {
      const eventDate = new Date(event.startTime);
      eventDate.setHours(0, 0, 0, 0);
      const fromDate = new Date(activeFilters.dateFrom!);
      fromDate.setHours(0, 0, 0, 0);
      return eventDate >= fromDate;
    });
  }
  
  // Date range filter: events <= dateTo (normalized to midnight)
  if (activeFilters.dateTo) {
    filtered = filtered.filter((event) => {
      const eventDate = new Date(event.startTime);
      eventDate.setHours(0, 0, 0, 0);
      const toDate = new Date(activeFilters.dateTo!);
      toDate.setHours(0, 0, 0, 0);
      return eventDate <= toDate;
    });
  }
  
  return filtered;
}, [events, activeFilters]);
```

**Architectural Differences vs Audit/Specials:**

| Aspecto              | Audit                 | Specials              | **Cover Time**           |
|----------------------|-----------------------|-----------------------|--------------------------|
| **User Role**        | Supervisor            | Supervisor            | **Supervisor**           |
| **Form Component**   | ❌ NO FORM            | ❌ NO FORM            | ❌ **NO FORM**           |
| **Filter Component** | ✅ SÍ (3 campos)      | ❌ No filters         | ✅ **SÍ (3 campos)**     |
| **Primary Action**   | Search & Filter       | Review & Approve      | **Search & Filter**      |
| **Data Scope**       | All operator events   | Escalated events      | **Completed covers**     |
| **Data Source**      | All Daily Events      | Promoted Daily Events | **Covers table**         |
| **Purpose**          | General compliance    | Escalation queue      | **Coverage analysis**    |
| **Columns**          | 8 columns             | 9 columns             | **7 columns**            |
| **Date Range**       | Single date (Desde)   | No date filter        | **Range (Desde/Hasta)**  |
| **Special Feature**  | Site filter           | Status badges         | **Duration tracking**    |

**Why NO FORM?**
- Cover Time es **view-only** de covers existentes
- Covers son **creados por operadores** en Covers module (future)
- Propósito es **auditoría de tiempo y análisis**, no creación
- Supervisores solo **buscan, filtran, y analizan** cover times

**Why Date Range (Desde/Hasta)?**
- Cover Time requiere **análisis temporal** (¿cuánto tiempo de cover en la semana?)
- Diferencia vs Audit (single date): **propósito diferente**
- Date range permite **estadísticas agregadas** (total time, average duration)
- Legacy UI muestra **Desde y Hasta** (ver imagen de referencia)

**Color Coding Purpose:**
- **Visual identification** de covers anormales (emergencias)
- **Quick scanning** de razones en tabla grande
- **Priority indication:** Red emergencies stand out
- **Expected behavior:** Green/Yellow/Blue indicate normal operations

**Future Features (Roadmap):**
1. **Backend Integration** - Replace mockCoverTimeEvents con `useCoverTimeEvents(filters, pagination)` hook
   - API call: GET /api/covers/completed?user=X&dateFrom=Y&dateTo=Z
   - Server-side filtering y pagination
   - Real-time updates (opcional)

2. **Advanced Filtering** - Enhanced search capabilities
   - Replace text input con dropdown (user list from backend)
   - Filter by reason (Break, Baño, Lunch, Emergencia)
   - Filter by duration range (covers > 15 min, < 5 min)
   - Filter by cover provider

3. **Statistics Dashboard** - Analytics view
   - Total cover time por operador (sum duration)
   - Average cover duration por operador
   - Cover time trends (charts)
   - Alertas para covers excesivamente largos
   - Comparison entre operadores (productivity insights)

4. **Export Functionality** - Reports generation
   - Export to PDF (requerido por legacy system)
   - Export to Excel (optional)
   - Email reports (daily/weekly cover time summaries)
   - Custom report builder

5. **Integration with Covers Module** - Linking
   - Link to pending covers (covers en progreso)
   - Link to programmed covers (covers_programados)
   - Cover request approval workflow integration
   - Emergency cover tracking

**Legacy System Compliance:**
Basado en `legacy_desktop_functional_context.md` sección 3.4:
- ✅ Covers module: Solicitud, Registro, Cola de espera
- ✅ Table: covers (cover time tracking)
- ✅ Filter by user (Usuario)
- ✅ Filter by date range (Desde/Hasta)
- ✅ Read-only audit view
- ✅ Duration tracking (HH:MM:SS format)
- ✅ Cover provider tracking (coveredBy)
- ✅ Reason categorization (Break, Baño, Emergencia)
- ⏳ Statistics: Pendiente (total time, average duration)
- ⏳ Export functionality: Pendiente (PDF, Excel)

**Performance Considerations:**
- **Client-side filtering:** O(n) per filter (acceptable para <1000 covers)
- **useMemo optimization:** Re-filters only when events or activeFilters change
- **Pagination default:** 10 items per page (adjustable)
- **Future:** Server-side filtering required para >1000 covers
- **Future:** Virtual scrolling si table rows >100
- **Duration calculations:** Client-side for now, move to backend for aggregates

**Related ADRs:** 
- ADR-004 (TanStack Table)
- ADR-006 (Role-Based Auth)
- ADR-008 (Specials Events Feature - clean table design pattern)
- ADR-009 (Audit Trail Feature - filtering pattern)
- ADR-010 (Cover Time Feature)

**Related Files:**
- `pages/CoverTimePage.tsx` - Page container con filters + results summary + table + development notice
- `App.tsx` - Routing integration (AppView includes "coverTime")
- `Topbar.tsx` - Nav item "Cover Time" para supervisor role
- `SupervisorPage.tsx` - "Cover Time" card (updated from "Cover Requests", yellow glow)

---

## Pages

### `DailyPage.tsx`
- **Role:** Operador
- **Features:** DailyEventForm + DailyEventTable
- **State:** Local state con useState
- **Layout:** MainLayout wrapper

### `CoversPage.tsx`
- **Role:** Operador
- **Features:** CoverForm + CoversTable
- **State:** Local state con useState
- **Layout:** MainLayout wrapper

### `SupervisorPage.tsx`
- **Role:** Supervisor/Lead Supervisor/Admin
- **Features:** MagicBento dashboard con 4 cards
  1. **Specials Events** (onClick → SpecialsPage, glowColor: blue)
  2. **Audit** (onClick → AuditPage, glowColor: violet)
  3. **Cover Time** (onClick → CoverTimePage, glowColor: yellow)
  4. **Team Stats** (future)
- **Dashboard Stats:**
  - specialsEvents: { total: 0, icon: "⚡" }
  - auditEvents: { total: 0, icon: "👁️" }
  - coverRequests: { total: 0, icon: "🔄" }
  - teamStats: { total: 0, icon: "📊" }
- **Layout:** MainLayout wrapper
- **Grid:** lg:grid-cols-4 (updated from 3 to accommodate 4 cards)
- **Related ADR:** ADR-007 (MagicBento Component)

### `SpecialsPage.tsx`
- **Role:** Supervisor/Lead Supervisor/Admin
- **Features:** Stats summary (4 cards) + SpecialsTable
- **State:** Local state + pagination control
- **Layout:** MainLayout wrapper
- **Future:** Supervisor action buttons, filters, export

### `AuditPage.tsx`
- **Role:** Supervisor/Lead Supervisor/Admin
- **Features:** AuditFilters (search UI) + Results Summary + AuditTable
- **State:** 
  - events: mockAuditEvents (TODO: replace with useAuditEvents hook)
  - pagination: { pageIndex: 0, pageSize: 10 }
  - activeFilters: AuditFilters type
- **Filtering Logic:** Client-side with useMemo (user, site, dateFrom)
- **Results Summary:** Shows filtered count and applied filters
- **Layout:** MainLayout wrapper
- **Future:** 
  - Backend integration (useAuditEvents hook)
  - Server-side filtering and pagination
  - Dropdown filters (Usuario, Sitio from API)
  - Date range picker (Fecha Hasta)
  - Export functionality (PDF, Excel)
  - Operator statistics dashboard
- **Related ADR:** ADR-009 (Audit Trail Feature)

### `CoverTimePage.tsx`
- **Role:** Supervisor/Lead Supervisor/Admin
- **Features:** CoverTimeFilters (search UI) + Results Summary + CoverTimeTable + Development Notice
- **State:** 
  - events: mockCoverTimeEvents (TODO: replace with useCoverTimeEvents hook)
  - pagination: { pageIndex: 0, pageSize: 10 }
  - activeFilters: CoverTimeFilters type
- **Filtering Logic:** Client-side with useMemo (user, dateFrom, dateTo)
- **Results Summary:** Shows filtered count and applied filters (with badges)
- **Section Title:** "Covers Completados" with event count
- **Layout:** MainLayout wrapper
- **Future:** 
  - Backend integration (useCoverTimeEvents hook)
  - Server-side filtering and pagination
  - Dropdown filter (Usuario from API)
  - Filter by reason (Break, Baño, Emergencia)
  - Export functionality (PDF, Excel)
  - Statistics dashboard (total time, average duration per operator)
  - Alert system for excessive cover times
  - Duration aggregates calculation
- **Related ADR:** ADR-010 (Cover Time Feature)

---

## Shared Components

### `shared/components/DotGrid/`
Background animated dot grid (GSAP animations).

### `shared/components/PillNav/`
Animated pill navigation con GSAP (usado en Topbar).

### `shared/components/MagicBento/`
Custom animated bento grid component.

**Structure:**
```
shared/components/MagicBento/
├── MagicBento.tsx               # Main animated container (280 líneas)
├── MagicBentoItem.tsx           # Content structure component (50 líneas)
├── types.ts                     # MagicBentoProps, MagicBentoItemProps
└── index.ts                     # Barrel exports
```

**Effects:**
- Spotlight (following cursor)
- Border glow (hover animation)
- Star particles (CSS keyframes)
- 3D Tilt (GSAP rotateX/Y)
- Click ripple (GSAP scale animation)
- Magnetism (distance-based attraction)

**Props:**
- `onClick?: () => void` - Custom click handler for navigation (added in ADR-008)
- `enableStars`, `enableSpotlight`, `enableBorderGlow`, `enableTilt`, `clickEffect`, `enableMagnetism`
- `spotlightRadius?: number` (default 300px)
- `particleCount?: number` (default 12)
- `glowColor?: string` (RGB values, e.g., "59, 130, 246")
- `disableAnimations?: boolean` (mobile fallback)

**Related ADR:** ADR-007 (Custom MagicBento Implementation)

### `Topbar.tsx`
Navigation bar con role-based nav items.

**Nav Items por Role:**
- **Operador:** Daily, Covers
- **Supervisor:** Dashboard, Specials
- **Admin:** Dashboard (future: Users, Settings)

### `Sidebar.tsx`
Sidebar component (currently minimal functionality).

---

## Routing Strategy

**Approach:** Context-based routing con `AppContext` (ADR-005)

**AppView Type:**
```typescript
type AppView = "login" | "daily" | "covers" | "supervisor" | "specials";
```

**AppContext:**
```typescript
{
  currentView: AppView;
  setCurrentView: (view: AppView) => void;
  currentUser: User | null;
  logout: () => void;
}
```

**Role-Based Routing Logic (App.tsx):**
```typescript
// Operador views
{currentUser?.role === "operador" && currentView === "daily" && <DailyPage />}
{currentUser?.role === "operador" && currentView === "covers" && <CoversPage />}

// Supervisor views
{(supervisor || lead_supervisor || admin) && currentView === "supervisor" && <SupervisorPage />}
{(supervisor || lead_supervisor || admin) && currentView === "specials" && <SpecialsPage />}
```

**Navigation Flow Examples:**
1. **Login → Daily:** Operador login → handleLoginSuccess → setCurrentView("daily")
2. **Login → Dashboard:** Supervisor login → handleLoginSuccess → setCurrentView("supervisor")
3. **Dashboard → Specials:** Click Specials card → onClick={() => setCurrentView("specials")}
4. **Topbar Navigation:** Click "Specials" nav item → setCurrentView("specials")

**Related ADRs:** 
- ADR-005 (Context-based Routing)
- ADR-006 (Role-Based Auth)

---

## State Management

**Current Strategy:** Local state con `useState` (component-level)

**Rationale:**
- Simple requirements (Milestone 1 = frontend only, mock data)
- No global state necesario
- Context API solo para routing y user state
- No Zustand/Redux overkill para fase actual

**Future Considerations:**
- Backend integration → API state management (React Query/SWR)
- Global filters → Zustand/Context
- Real-time updates → WebSocket state

---

## Data Flow Patterns

### Feature Module Data Flow

```
Page Component (container)
  ↓
  useState (local state)
  ↓
  Feature Components (presentational)
    ├── Table Component (data via props)
    └── Form Component (callbacks via props)
```

**Example (DailyPage):**
```typescript
DailyPage (useState events)
  ↓
  DailyEventForm → onAddEvent callback → updates events state
  ↓
  DailyEventTable ← events prop (read-only)
```

**Example (SpecialsPage):**
```typescript
SpecialsPage (useState events, pagination)
  ↓
  Stats Summary (calculated from events)
  ↓
  SpecialsTable ← events, pagination, onPaginationChange props
```

---

## TypeScript Conventions

1. **Interfaces over Types:** Prefer `interface` for props y domain models
2. **Strict Mode:** `verbatimModuleSyntax`, no implicit any
3. **Barrel Exports:** index.ts exporta tipos y componentes
4. **Type Guards:** Validación en runtime cuando necesario
5. **Props Interfaces:** Nombradas `[Component]Props`
6. **Domain Types:** Nombrados según entidad (User, DailyEvent, SpecialEvent)

**Example:**
```typescript
// types.ts
export interface SpecialEvent { ... }
export interface SpecialsFilters { ... }

// components/SpecialsTable.tsx
interface SpecialsTableProps {
  data: SpecialEvent[];
  isLoading?: boolean;
  error?: string | null;
  pagination?: PaginationState;
  onPaginationChange?: OnChangeFn<PaginationState>;
}
```

---

## Styling Conventions

**Approach:** TailwindCSS utility classes (inline)

**Custom Colors (tailwind.config.js):**
- `sigBlue`: #3B82F6
- `sigContainer`: #14181F
- `sigBorder`: #1E293B
- `sigDark`: #0A0E14
- `sigHover`: #1F2937

**Conditional Styling Examples:**
```typescript
// Status badges
status === "pendiente" ? "bg-yellow-500/10 text-yellow-400" : 
status === "enviado" ? "bg-blue-500/10 text-blue-400" :
"bg-green-500/10 text-green-400"

// Priority badges
priority === "critical" ? "bg-red-500/10 text-red-400" :
priority === "high" ? "bg-orange-500/10 text-orange-400" :
...
```

---

## Testing Strategy (Future)

**Current State:** No tests implementados (Milestone 1 = MVP)

**Planned Approach:**
1. **Unit Tests:** Vitest + React Testing Library
   - Type guards
   - Column accessors
   - Utility functions

2. **Integration Tests:**
   - Component interactions
   - Form submissions
   - Navigation flows

3. **E2E Tests:** Playwright
   - Login flow
   - Role-based routing
   - CRUD operations

---

## Performance Optimization

**Current Optimizations:**
- Tree-shaking enabled (Vite + ESM)
- GSAP hardware-accelerated animations
- TanStack Table virtualization ready (cuando >100 rows)
- Lazy loading components (future)

**Bundle Size (Current):**
- Total: 334.18 kB (108.98 kB gzipped)
- TanStack Table: ~40-50 kB
- GSAP: ~50 kB
- React 19: ~150 kB

**Future Optimizations:**
- Code splitting por route
- Lazy load MagicBento animations
- Image optimization
- API response caching

---

### 7. `features/stationMap/` - Central Station Map (Supervisor)

**Purpose:** Visualización del Central Station workspace para monitoreo en tiempo real del estado de workstations y operadores (rol supervisor/lead_supervisor).

**Structure:**
```
features/stationMap/
├── types.ts                     # Domain types (85 líneas)
│   ├── WorkstationStatus (const object as const)
│   ├── WorkstationStatusType (type literal)
│   ├── Workstation interface
│   ├── WORKSTATION_STATUS_COLORS mapping
│   └── WORKSTATION_STATUS_LABELS (Spanish)
│
├── components/
│   └── StationMap.tsx           # SVG visualization component (60 líneas)
│       ├── Props: className?: string
│       ├── Container: useRef<HTMLDivElement>
│       ├── Aspect ratio: 16:9 responsive container
│       └── SVG inline via dangerouslySetInnerHTML
│
└── index.ts                     # Barrel exports
```

**Key Types:**
```typescript
// WorkstationStatus const object (erasableSyntaxOnly compatible)
export const WorkstationStatus = {
  AVAILABLE: 'available',
  OCCUPIED: 'occupied',
  OFFLINE: 'offline',
  ON_BREAK: 'on_break',
  ALERT: 'alert',
} as const;

export type WorkstationStatusType = typeof WorkstationStatus[keyof typeof WorkstationStatus];

// Workstation interface (maps to SVG group IDs)
export interface Workstation {
  id: string;                    // e.g., "WS_60", "WS_62"
  status: WorkstationStatusType;
  operatorName?: string;
  operatorId?: number;
  lastUpdate?: string;
  alertMessage?: string;
}

// Color mapping for visual status representation
export const WORKSTATION_STATUS_COLORS: Record<string, string> = {
  [WorkstationStatus.AVAILABLE]: '#10b981',   // green-500
  [WorkstationStatus.OCCUPIED]: '#3b82f6',    // blue-500
  [WorkstationStatus.OFFLINE]: '#6b7280',     // gray-500
  [WorkstationStatus.ON_BREAK]: '#f59e0b',    // amber-500
  [WorkstationStatus.ALERT]: '#ef4444',       // red-500
};
```

**Components:**

1. **StationMap.tsx** (60 líneas)
   - **Role:** SVG visualization component
   - **Props:**
     * `className?: string` - Optional custom styling
   - **Features (Phase 1 - Current):**
     * Display static SVG workspace layout
     * Responsive container (16:9 aspect ratio)
     * Dark theme matching app design
   - **Features (Phase 2 - Future):**
     * Real-time WebSocket updates
     * Color coding based on WorkstationStatus
     * Interactive click handlers (show operator details)
     * Hover tooltips (operatorName, status, lastUpdate)
     * Glow effect for alerts
   - **Implementation:**
     ```typescript
     const StationMap = ({ className = '' }: StationMapProps) => {
       const containerRef = useRef<HTMLDivElement>(null);
       
       // Import SVG as raw string
       import workspaceMapSVG from '../../assets/maps/workspace_map.svg?raw';
       
       useEffect(() => {
         // TODO (Phase 2): Add WebSocket connection
         // TODO (Phase 2): Apply status colors to SVG groups
         // TODO (Phase 2): Add click/hover handlers
       }, []);
       
       return (
         <div ref={containerRef} className="...">
           <div style={{ paddingBottom: '56.25%' /* 16:9 */ }}>
             <div dangerouslySetInnerHTML={{ __html: workspaceMapSVG }} />
           </div>
         </div>
       );
     };
     ```

**Asset Structure:**
```
src/assets/maps/
└── workspace_map.svg            # Central Station workspace layout (431 líneas)
    ├── Dimensions: 1600x900 (16:9 aspect ratio)
    ├── Dark theme: #0f1115 background
    ├── Style classes: .desk, .screen, .chair, .table, .zone
    ├── Workstation groups: <g id="WS_XX" transform="translate(x,y)">
    ├── Filter effect: #glow (for future alerts)
    └── ~40 workstations + 4 supervisor spaces
```

**Workstation IDs (SVG Structure):**
- **Left Column:** WS_60, WS_62, WS_63, WS_24_left, WS_28_left, WS_25_left, WS_30, WS_26_left, WS_16, WS_27_left, WS_31
- **Center Left:** WS_36 (IT3), WS_35 (IT2), WS_34 (IT1), WS_33 (Lead Supervisor), WS_17_center, WS_20, WS_18_center, WS_21, WS_19_center, WS_22, WS_23_center (Supervisor)
- **Center Right:** WS_17, WS_18, WS_19, WS_32 (Lead Supervisor), WS_10_right, WS_13, WS_11, WS_10_right2, WS_12, WS_15, WS_23 (Supervisor)
- **Right Column:** WS_24, WS_25, WS_26, WS_27, WS_1, WS_8, WS_2, WS_7, WS_3, WS_6, WS_4, WS_5, WS_9 (Supervisor)

**Page Implementation:**
```typescript
// src/pages/StationMapPage.tsx (95 líneas)
export const StationMapPage = () => {
  return (
    <MainLayout>
      <div className="space-y-6">
        <h1>Central Station Map</h1>
        <p>Visualización del estado de las estaciones de trabajo</p>
        
        {/* Development Notice */}
        <div className="bg-blue-500/10 ...">
          <h3>Modo de desarrollo - Vista estática</h3>
          <p>Funcionalidades en desarrollo:</p>
          <ul>
            <li>Actualización en tiempo real (WebSocket)</li>
            <li>Código de colores por estado</li>
            <li>Selección interactiva de estaciones</li>
            <li>Tooltips con información del operador</li>
            <li>Filtros por estado y zona</li>
            <li>Leyenda y controles de zoom/pan</li>
            <li>Notificaciones de alertas (glow effect)</li>
            <li>Exportar snapshot</li>
          </ul>
        </div>
        
        {/* Station Map Visualization */}
        <div className="bg-gray-900 rounded-lg p-6 border border-gray-800">
          <StationMap />
        </div>
        
        {/* Future: Status Summary Cards, Active Alerts, Recent Changes */}
      </div>
    </MainLayout>
  );
};
```

**Routing Integration:**
```typescript
// App.tsx
export type AppView = "login" | "daily" | "covers" | "supervisor" | 
                      "specials" | "audit" | "coverTime" | "stationMap";

// SupervisorPage.tsx
<MagicBento onClick={() => setCurrentView("stationMap")} glowColor="34, 197, 94">
  <MagicBentoItem title="Central Station Map" ... />
</MagicBento>

// Topbar.tsx
case "supervisor":
  return [
    { label: 'Dashboard', value: 'supervisor' },
    { label: 'Specials', value: 'specials' },
    { label: 'Audit', value: 'audit' },
    { label: 'Cover Time', value: 'coverTime' },
    { label: 'Station Map', value: 'stationMap' },  // NEW
  ];
```

**Current Implementation (Phase 1):**
- ✅ Static SVG display
- ✅ Responsive container (16:9 aspect ratio)
- ✅ Dark theme matching app design
- ✅ Type definitions ready for Phase 2
- ❌ No real-time updates (hardcoded SVG)
- ❌ No color coding (SVG default colors)
- ❌ No interactivity (no click/hover)

**Future Implementation (Phase 2 - Backend Ready):**
- Real-time WebSocket connection: `ws://localhost:8000/ws/stations/`
- Color coding based on WorkstationStatus:
  ```typescript
  const updateWorkstationStatus = (data: WorkstationUpdate) => {
    const svgGroup = document.getElementById(data.workstationId);
    const desk = svgGroup?.querySelector('.desk');
    const color = WORKSTATION_STATUS_COLORS[data.status];
    if (desk) desk.setAttribute('fill', color);
    
    // Apply glow for alerts
    if (data.status === WorkstationStatus.ALERT) {
      svgGroup?.setAttribute('filter', 'url(#glow)');
    }
  };
  ```
- Interactive click handlers:
  ```typescript
  ws.addEventListener('click', () => {
    const workstationId = ws.getAttribute('id');
    showOperatorDetailsModal(workstationId);
  });
  ```
- Hover tooltips with operator info
- Status filters (Available, Occupied, etc.)
- Zoom/pan controls (d3-zoom or custom)
- Status legend component
- Export snapshot functionality

**API Integration Points (Phase 2):**
```typescript
// Future hooks
hooks/
├── useStationMap.ts             # GET /api/stations/map
├── useStationStatus.ts          # WebSocket connection
└── useWorkstationDetails.ts     # GET /api/stations/:id
```

**Diferencias vs Audit/Cover Time:**
- **Data Type:** Spatial visualization (SVG) vs Tabular data (TanStack Table)
- **Purpose:** Real-time monitoring vs Historical audit
- **Interactivity:** Click/hover workstations vs Filter/sort table rows
- **Update Frequency:** Real-time WebSocket vs On-demand query
- **Component Type:** SVG container vs Table component

**Related ADRs:** 
- ADR-011 (Central Station Map Module)
- ADR-005 (Context-based routing)
- ADR-006 (Role-based authentication)
- ADR-007 (MagicBento navigation)

**Dependencies:**
- React 19.2.0 (useEffect, useRef)
- TypeScript 5.9.3 (strict mode)
- Vite 7.3.1 (SVG ?raw import)
- GSAP 3.14.2 (MagicBento navigation)

**Files Created:**
- `src/assets/maps/workspace_map.svg` (431 líneas)
- `src/features/stationMap/types.ts` (85 líneas)
- `src/features/stationMap/components/StationMap.tsx` (60 líneas)
- `src/features/stationMap/index.ts` (14 líneas)
- `src/pages/StationMapPage.tsx` (95 líneas)

**Total Code:** ~685 líneas TypeScript + 431 líneas SVG

**Future Enhancements:**
- 🔄 Phase 2: Real-time WebSocket updates, color coding, interactivity
- 🔄 Phase 3: Status filters, legend, zoom/pan controls
- 🔄 Phase 4: Enhanced UX (animations, sound alerts, historical playback)
- 🔄 Phase 5: Analytics integration (status summary, timeline, alerts panel)

---

## Migration Path to Backend

**When Backend is Ready:**

1. **Replace Mock Data:**
   ```typescript
   // Before:
   const [events] = useState(mockSpecialEvents);
   
   // After:
   const { data: events, isLoading, error } = useSpecialEvents();
   ```

2. **Add API Hooks:**
   ```
   features/specials/
   └── hooks/
       ├── useSpecialEvents.ts          # GET /api/specials
       ├── useUpdateSpecialStatus.ts    # PUT /api/specials/:id/status
       └── useReassignSpecial.ts        # PUT /api/specials/:id/assign
   ```

3. **Update Components:**
   - Add loading states (skeleton loaders)
   - Add error handling (error boundaries)
   - Add optimistic updates
   - Add refetch logic

4. **Delete Mock Files:**
   - Search codebase para "TODO: DELETE WHEN BACKEND"
   - Remove mockData.ts files
   - Remove MOCK_USERS en auth/api.ts

---

## Conclusion

Esta estructura modular permite:
- ✅ Desarrollo paralelo de features
- ✅ Testing aislado por módulo
- ✅ Reusabilidad de componentes
- ✅ Escalabilidad horizontal (nuevos features)
- ✅ Migraciones incrementales (mock → API)
- ✅ Onboarding rápido (estructura predecible)

**Next Steps:**
- Implementar backend API integration
- Agregar supervisor actions (approve/reject)
- Implementar filtering avanzado
- Agregar export functionality
- Testing suite completo
