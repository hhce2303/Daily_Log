# Catalogs API — Endpoint Report

**Date:** 2026-04-10  
**Scope:** Backend — `apps/core/` (selectors, views, serializers, urls)  
**Status:** Implemented & validated against production DB

---

## Endpoints

### 1. `GET /api/v1/catalogs/sites/`

**Propósito:** Retorna el catálogo completo de sitios monitoreados. Cada sitio incluye su ID concatenado al nombre para facilitar identificación en dropdowns del frontend.

**Auth:** Bearer JWT (IsAuthenticated)  
**Tabla:** `daily_sites`  
**Query:** `SELECT ID_site, site_name FROM daily_sites ORDER BY site_name`

**Response:**
```json
[
  { "id": 305, "site_name": "305 - AS 3281 Storage Lot" },
  { "id": 165, "site_name": "165 - AS Atwell Prep Center" },
  { "id": 124, "site_name": "124 - AS Audi of North Atlanta" }
]
```

**Datos:** 204 sitios activos.

---

### 2. `GET /api/v1/catalogs/activities/`

**Propósito:** Retorna el catálogo completo de tipos de actividad disponibles para registrar eventos diarios.

**Auth:** Bearer JWT (IsAuthenticated)  
**Tabla:** `daily_activities`  
**Query:** `SELECT ID_activity, act_name FROM daily_activities ORDER BY act_name`

**Response:**
```json
[
  { "id": 3, "act_name": "Break" },
  { "id": 99, "act_name": "Call" },
  { "id": 44, "act_name": "Start Shift" }
]
```

**Datos:** 144 actividades registradas.

---

## Arquitectura

Siguiendo el patrón Selector → View → URL (Read Path):

| Capa | Archivo | Responsabilidad |
|------|---------|-----------------|
| **Selector** | `apps/core/selectors.py` | Queries optimizadas de solo lectura. `get_all_sites()` concatena ID al nombre. `get_all_activities()` retorna valores directos. |
| **View** | `apps/core/views.py` | Orquestación pura — llama al selector y retorna Response. Sin lógica. |
| **Serializer** | `apps/core/serializers.py` | `SiteCatalogSerializer` y `ActivityCatalogSerializer` — solo para documentación OpenAPI via drf-spectacular. |
| **URL** | `apps/core/urls.py` | Rutas bajo `/api/v1/catalogs/` |

---

## Decisiones Técnicas

1. **ID concatenado al nombre del sitio:** El frontend necesita mostrar el ID junto al nombre para que los operadores identifiquen rápidamente el sitio. El formato `"ID - site_name"` se genera en el selector, no en el serializer (el serializer no tiene lógica).

2. **Sin paginación:** Los catálogos son datasets pequeños y estáticos (204 sitios, 144 actividades). Se cargan completos para cachear en el frontend con `useCatalogs()`.

3. **`only()` en queries:** Se seleccionan solo las columnas necesarias para minimizar transferencia de datos.

4. **Selector pattern vs ViewSet:** Se usan `APIView` + selectors en vez de `ModelViewSet` porque son endpoints de solo lectura sin necesidad de CRUD, filtros ni paginación.

---

## Compatibilidad Frontend

Estos endpoints satisfacen el contrato definido en `daily_events_frontend_implementation.md`:

| Contrato Frontend | Endpoint Backend | Estado |
|-------------------|-----------------|--------|
| `GET /api/v1/catalogs/sites/` | `apps/core/urls.py → SiteListView` | Implementado |
| `GET /api/v1/catalogs/activities/` | `apps/core/urls.py → ActivityListView` | Implementado |

La respuesta JSON coincide exactamente con lo esperado por `features/logs/api.ts` (`fetchSites`, `fetchActivities`).

---

## Validación

- `python manage.py check` → 0 errores
- Selector test contra BD real:
  - Sites: 204 registros, formato `"ID - site_name"` correcto
  - Activities: 144 registros, ordenadas por `act_name`
- Documentación OpenAPI disponible en `/api/docs/`
