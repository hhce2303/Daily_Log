# Daily Log 2.0 — Sistema Enterprise de Monitoreo y Bitácora de Operaciones

> **SIG Systems, Inc.** — Plataforma web para estaciones centrales de vigilancia  
> Migración de aplicación desktop Python/Tkinter a arquitectura web moderna full-stack.

---

## Tabla de Contenidos

1. [Visión del Sistema](#1-visión-del-sistema)
2. [Arquitectura General](#2-arquitectura-general)
3. [Backend — Django REST API](#3-backend--django-rest-api)
4. [Frontend — React + TypeScript](#4-frontend--react--typescript)
5. [Docker e Infraestructura](#5-docker-e-infraestructura)
6. [Base de Datos](#6-base-de-datos)
7. [Autenticación y Seguridad](#7-autenticación-y-seguridad)
8. [Módulos del Sistema](#8-módulos-del-sistema)
9. [Configuración del Entorno](#9-configuración-del-entorno)
10. [Comandos Esenciales](#10-comandos-esenciales)
11. [Escalabilidad](#11-escalabilidad)
12. [Estado Actual del Proyecto](#12-estado-actual-del-proyecto)

---

## 1. Visión del Sistema

**Daily Log 2.0** es una aplicación web enterprise para gestionar las operaciones diarias de una central de monitoreo de seguridad. El sistema permite a operadores registrar eventos, a supervisores revisar actividades especiales y gestionar coberturas, y a administradores controlar el acceso y la configuración.

### Contexto de Origen

El sistema proviene de una **aplicación de escritorio Python/Tkinter** (`proyecto_app`) que se conectaba directamente a MySQL. Daily Log 2.0 expone esa misma base de datos a través de una API REST, manteniendo compatibilidad total con la estructura existente sin modificar tablas ni migrarlas.

### Roles

| Rol | Descripción |
|-----|-------------|
| **Operador** | Registro de eventos diarios, solicitudes de cover |
| **Supervisor** | Dashboard, eventos especiales, mapa de estaciones, gestión de covers |
| **Lead Supervisor** | Capacidades de supervisor + gestión avanzada |
| **Admin** | Acceso completo al sistema y configuración |

> **Para uso del sistema:** consultar el manual de usuario disponible en el equipo de supervisión.

---

## 2. Arquitectura General

```
┌─────────────────────────────────────────────────────────────────┐
│                        NAVEGADOR WEB                            │
│                   React 19 + TypeScript + Vite                  │
│                     Puerto 5173 (desarrollo)                    │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTP/REST (JWT)
                          │ VITE_API_URL=http://localhost:8000/api/v1
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                     DOCKER CONTAINER                            │
│              Django 5 + DRF + Gunicorn (3 workers)              │
│                     Puerto 8000                                 │
│                                                                 │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐   │
│  │  core    │  │  users   │  │  logs    │  │notifications │   │
│  │  audit   │  │ platform │  │ reports  │  │  schedules   │   │
│  │inventory │  │ sigtools │  └──────────┘  └──────────────┘   │
│  └──────────┘  └──────────┘                                    │
└─────────────────────────┬───────────────────────────────────────┘
                          │ mysqlclient
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│                   MySQL 5.7+  (remoto)                          │
│              72.167.56.142:3306 / sig_dailylogs                 │
└─────────────────────────────────────────────────────────────────┘
```

**Patrón arquitectónico:** Monolito modular con separación estricta por capas dentro de cada app Django:
- `models.py` → ORM (managed=False, tablas existentes)
- `selectors.py` → queries de solo lectura
- `services.py` → lógica de negocio / escritura
- `serializers.py` → contrato de datos con el frontend
- `views.py` + `urls.py` → endpoints REST

---

## 3. Backend — Django REST API

### Stack

| Componente | Versión |
|------------|---------|
| Python | 3.12 |
| Django | 5.1.x |
| Django REST Framework | 3.15.x |
| SimpleJWT | 5.3.x |
| drf-spectacular | 0.28.x (OpenAPI/Swagger) |
| django-filter | 24.x |
| mysqlclient | 2.2.x |
| Gunicorn | producción |
| Whitenoise | archivos estáticos |

### Estructura de Apps

```
daily-log-backend/
├── config/                  # Configuración global Django
│   ├── settings/
│   │   ├── base.py          # Settings compartidos
│   │   ├── development.py   # DEBUG=True, sin HTTPS
│   │   └── production.py    # Gunicorn, WhiteNoise, seguridad
│   ├── urls.py              # Router principal
│   └── db_router.py         # Router multi-base de datos
│
├── apps/
│   ├── core/                # Modelos de catálogo (Site, Activity, Season, Offsets)
│   │                        # Paginación, permisos base, excepciones comunes
│   ├── users/               # Auth: User, Role, Session
│   ├── logs/                # DailyEvent — CRUD principal de operadores
│   ├── notifications/       # Special events — revisión de supervisores
│   ├── audit/               # Registro de acciones del sistema
│   ├── reports/             # Generación de reportes
│   ├── inventory/           # Inventario de recursos
│   ├── schedules/           # Programación de turnos
│   ├── platform/            # Config de plataforma / estaciones
│   └── sigtools/            # Herramientas internas SIG
│
├── requirements/
│   ├── base.txt             # Dependencias comunes
│   ├── development.txt      # + debug-toolbar, ipython
│   ├── production.txt       # + gunicorn
│   └── test.txt             # + pytest, coverage
│
└── docker/
    ├── Dockerfile           # Multi-stage build (builder + runtime)
    ├── docker-compose.yml
    └── entrypoint.sh
```

### Principios de Diseño

- **`managed = False`** en todos los modelos que mapean tablas existentes — Django nunca altera el esquema.
- **Selectors vs Services**: queries en `selectors.py`, escritura/lógica en `services.py`. Las vistas solo orquestan.
- **Timezone**: `USE_TZ=True`. La BD almacena `DATETIME` sin zona horaria. El backend convierte de UTC a hora local del sitio antes de escribir, usando la tabla de offsets `daily_summer_offsets` / `daily_winter_offsets` (offsets relativos a Colombia UTC-5).
- **Errores estructurados**: excepciones personalizadas en `apps/core/exceptions.py` para respuestas consistentes.

### Endpoints Principales

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/api/v1/auth/login/` | Obtener access + refresh token |
| POST | `/api/v1/auth/refresh/` | Renovar access token |
| POST | `/api/v1/auth/logout/` | Invalidar refresh token |
| GET | `/api/v1/events/` | Listar eventos del operador (filtros: date, site) |
| POST | `/api/v1/events/` | Crear evento diario |
| GET | `/api/v1/specials/` | Listar eventos especiales (supervisor) |
| PATCH | `/api/v1/specials/{id}/` | Marcar especial como revisado |
| GET | `/api/v1/health/` | Healthcheck del servicio |

> Documentación OpenAPI en: `http://localhost:8000/api/schema/swagger-ui/`

---

## 4. Frontend — React + TypeScript

### Stack

| Componente | Versión |
|------------|---------|
| React | 19.2.0 |
| TypeScript | 5.9.3 (strict mode) |
| Vite | 7.3.1 |
| TailwindCSS | 3.4.4 |
| TanStack Table | 8.21.3 |
| GSAP | 3.14.2 |
| lucide-react | 0.563.0 |

### Estructura del Proyecto

```
daily-log-frontend/react-ts/src/
├── features/                # Módulos de negocio
│   ├── auth/                # Login, tokens JWT, tipos de usuario
│   ├── logs/                # Daily Events (operador)
│   │   ├── components/      # DailyTable, EventForm, …
│   │   ├── hooks/           # useEvents, useCreateEvent, …
│   │   ├── EventsProvider   # Context + estado local de eventos
│   │   ├── columns.tsx      # Definición de columnas TanStack Table
│   │   └── types.ts
│   ├── specials/            # Specials Events (supervisor)
│   ├── covers/              # Cover Requests
│   ├── coverTime/           # Cover Time management
│   ├── dashboard/           # Dashboard supervisor
│   ├── stationMap/          # Mapa de estaciones
│   ├── audit/               # Auditoría
│   ├── reports/             # Reportes
│   └── users/               # Gestión de usuarios
│
├── shared/                  # Componentes y hooks reutilizables
├── hooks/                   # Hooks globales (useRowHighlight, …)
├── lib/
│   ├── api/client.ts        # Cliente HTTP + auto-refresh JWT
│   └── auth/tokens.ts       # decode / verify / save tokens
├── layouts/                 # Shell de la app (sidebar, header)
├── pages/                   # Páginas enrutadas por rol
└── app/                     # Bootstrap, router basado en Context
```

### Convenciones

- **Feature-based**: cada feature es autónoma con sus propios types, hooks, components y services.
- **Hooks para side effects**: toda llamada a la API vive en un hook custom (`useCreateEvent`, `useSpecials`, etc.).
- **No React Router**: el routing es por Context API basado en rol del usuario.
- **Dark theme**: Tailwind con `darkMode: ["class"]`, tema oscuro como default.
- **Fechas sin conversión doble**: el backend devuelve `spec_datetime` como ISO sin sufijo `Z` para que el browser no aplique conversión UTC→local por segunda vez.

### Variables de Entorno

```env
# daily-log-frontend/react-ts/.env
VITE_API_URL=http://localhost:8000/api/v1
```

---

## 5. Docker e Infraestructura

### Imagen del Backend

La imagen usa **multi-stage build** para minimizar tamaño:

| Stage | Propósito |
|-------|-----------|
| `builder` | Compila dependencias C (mysqlclient) con gcc |
| `runtime` | Solo runtime — sin herramientas de compilación |

```dockerfile
# Stage 1: Instalar dependencias
FROM python:3.12-slim AS builder
RUN pip install --prefix=/install -r requirements/production.txt

# Stage 2: Runtime limpio
FROM python:3.12-slim AS runtime
COPY --from=builder /install /usr/local
```

- Corre con **usuario no-root** (`django:django`)
- Healthcheck incorporado cada 30s contra `/api/v1/health/`
- `restart: unless-stopped` — se recupera automáticamente

### docker-compose.yml

```yaml
services:
  web:
    build: { context: .., dockerfile: docker/Dockerfile }
    container_name: daily-log-backend
    ports: ["8000:8000"]
    env_file: ../.env
    environment:
      - DJANGO_ENV=production
      - ALLOWED_HOSTS=localhost,127.0.0.1,0.0.0.0,192.168.101.135
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/v1/health/"]
      interval: 30s
      timeout: 5s
      retries: 3
```

### Comandos de Ciclo de Vida

```bash
# Ubicarse en el directorio de Docker
cd daily-log-backend/docker

# Primera vez / después de cambios en el código
docker compose build web
docker compose up -d

# Ver logs en vivo
docker logs -f daily-log-backend

# Ejecutar comando dentro del contenedor
docker exec daily-log-backend python manage.py shell

# Detener
docker compose down
```

> **Importante:** El código está **baked into** la imagen (no hay volume mounts).  
> Cualquier cambio en Python requiere `docker compose build web && docker compose up -d`.

---

## 6. Base de Datos

- **Motor:** MySQL 5.7+ (servidor remoto)
- **Host:** `72.167.56.142:3306`
- **Base de datos:** `sig_dailylogs`
- **Prefijo de tablas:** `daily_`

### Tablas Clave

| Tabla | Propósito |
|-------|-----------|
| `daily_users` | Credenciales de acceso |
| `daily_user_rol` | Roles del sistema |
| `daily_sesions` | Sesiones activas / históricas |
| `daily_sites` | Sitios monitoreados (con `site_timezone`) |
| `daily_activities` | Catálogo de actividades disponibles |
| `daily_events` | Bitácora principal de eventos |
| `daily_specials` | Eventos especiales para revisión de supervisores |
| `daily_season_offsets` | Temporada activa (verano/invierno) |
| `daily_summer_offsets` | Offsets de zona horaria (temporada verano) |
| `daily_winter_offsets` | Offsets de zona horaria (temporada invierno) |
| `daily_covers_solicitudes` | Solicitudes de cobertura |
| `daily_breaks` | Breaks programados |
| `daily_hc_sites` | Healthcheck por sitio |

### Política de Modelos

Todos los modelos que mapean tablas existentes tienen `managed = False`. Django **nunca** ejecuta `CREATE TABLE`, `ALTER TABLE` ni `DROP TABLE` sobre ellas. Las migraciones solo afectan tablas internas de Django (sesiones, tokens, etc.).

### Timezones

Los offsets en BD son **relativos a Colombia (UTC-5)**:

| Zona | Offset en BD | UTC equivalente |
|------|-------------|-----------------|
| ET (verano) | +1 | UTC-4 |
| CT | 0 | UTC-5 |
| MT | -1 | UTC-6 |
| PT | -2 | UTC-7 |

Fórmula de conversión: `hora_local_sitio = UTC + (offset − 5)`

---

## 7. Autenticación y Seguridad

- **JWT** via `rest_framework_simplejwt`: access token (vida corta) + refresh token (vida larga)
- **Token blacklist**: los refresh tokens se invalidan al hacer logout
- **CORS**: configurado en `django-cors-headers`, solo orígenes permitidos
- **Usuario no-root** en Docker
- **Permisos por rol**: mapeados a Django Groups/Permissions. Cada vista verifica el rol antes de responder.
- **Variables sensibles**: cargadas desde `.env` via `django-environ`, nunca hardcodeadas

### Variables de Entorno del Backend

```env
SECRET_KEY=...
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,192.168.101.135
DB_HOST=72.167.56.142
DB_PORT=3306
DB_NAME=sig_dailylogs
DB_USER=...
DB_PASSWORD=...
```

---

## 8. Módulos del Sistema

| Módulo | App Backend | Feature Frontend | Rol |
|--------|-------------|-----------------|-----|
| Daily Events | `apps.logs` | `features/logs` | Operador |
| Specials Events | `apps.notifications` | `features/specials` | Supervisor |
| Cover Requests | `apps.platform` | `features/covers` | Operador |
| Cover Time | `apps.platform` | `features/coverTime` | Supervisor |
| Dashboard | `apps.reports` | `features/dashboard` | Supervisor |
| Station Map | `apps.platform` | `features/stationMap` | Supervisor |
| Audit Log | `apps.audit` | `features/audit` | Supervisor |
| Reports | `apps.reports` | `features/reports` | Supervisor |
| Users Admin | `apps.users` | `features/users` | Admin |
| Healthcheck Sites | `apps.sigtools` | — | Interno |

---

## 9. Configuración del Entorno

### Requisitos

| Herramienta | Versión mínima |
|-------------|---------------|
| Docker Desktop | 4.x |
| Node.js | 20.x LTS |
| npm | 10.x |

> El backend NO requiere Python local — corre completamente en Docker.  
> El frontend NO requiere Docker — corre con `npm run dev` directamente.

### Setup Inicial — Backend

```bash
# 1. Crear archivo .env en daily-log-backend/
cp daily-log-backend/.env.example daily-log-backend/.env
# Completar las variables DB_*, SECRET_KEY, etc.

# 2. Build y levantado
cd daily-log-backend/docker
docker compose build web
docker compose up -d

# 3. Verificar que está activo
curl http://localhost:8000/api/v1/health/
```

### Setup Inicial — Frontend

```bash
cd daily-log-frontend/react-ts
npm install

# Crear .env con la URL del backend
echo "VITE_API_URL=http://localhost:8000/api/v1" > .env

npm run dev
# Disponible en http://localhost:5173
```

---

## 10. Comandos Esenciales

### Backend

```bash
# Rebuild después de cambios en código
cd daily-log-backend/docker
docker compose build web && docker compose up -d

# Logs en tiempo real
docker logs -f daily-log-backend

# Shell de Django
docker exec -it daily-log-backend python manage.py shell

# Ejecutar un script dentro del contenedor
docker cp script.py daily-log-backend:/tmp/script.py
docker exec daily-log-backend sh -c "cd /app && python manage.py shell < /tmp/script.py"

# Ver estado del healthcheck
docker inspect daily-log-backend --format='{{.State.Health.Status}}'
```

### Frontend

```bash
# Desarrollo con HMR
npm run dev

# Build de producción
npm run build

# Preview del build
npm run preview

# Lint
npm run lint
```

---

## 11. Escalabilidad

### Escalabilidad Horizontal (múltiples instancias)

El backend está preparado para escalar horizontalmente con cambios mínimos:

**Lo que ya es stateless:**
- Los endpoints REST no guardan estado en memoria — cada request es independiente.
- JWT no requiere sesión server-side (salvo el blacklist de refresh tokens).
- Los workers de Gunicorn (actualmente 3) pueden incrementarse ajustando el `CMD` en el Dockerfile.

**Pasos para escalar horizontalmente:**
1. Agregar un load balancer (nginx, Traefik, AWS ALB) delante de múltiples contenedores `web`.
2. Mover el token blacklist a Redis (`INSTALLED_APPS` ya incluye `simplejwt.token_blacklist` — solo cambiar el backend de almacenamiento).
3. Configurar `docker compose` con `replicas: N` o migrar a Kubernetes/ECS.

### Escalabilidad de Base de Datos

- La BD remota es el único punto de estado compartido — escalar la BD requiere MySQL replication o un proxy (ProxySQL).
- `db_router.py` ya está en su lugar para soportar múltiples bases de datos (lectura/escritura separados).
- Los modelos `managed=False` permiten cambiar el motor de BD sin tocar código de aplicación.

### Cache

El sistema actualmente no usa cache externo. Para cargas altas:
- Agregar **Redis** como cache backend (`django-redis`).
- Los selectores de solo lectura (`selectors.py`) son el candidato natural para cachear (catálogos de sites, activities, roles — datos semi-estáticos).
- TTL sugerido: 5 min para catálogos, 30s para datos operacionales.

### WebSockets (Tiempo Real)

Para reemplazar el polling que hacía la app desktop:
- **Django Channels** + **ASGI** (el `asgi.py` ya existe en `config/`).
- Requiere agregar `channels` y `channels_redis` a `requirements/base.txt`.
- Los eventos de nueva actividad (`DailyEvent`, `Special`) dispararían notificaciones push al frontend.
- El frontend ya usa Context API con estado local — integrar WebSockets requiere un provider adicional por feature.

### Tareas Asíncronas

Para healthchecks automáticos, limpieza de sesiones y reportes pesados:
- **Celery** + **Redis** como broker.
- Las tareas candidatas ya están identificadas en `apps/schedules/` y `apps/sigtools/`.

### Seguridad en Producción

Al desplegar en servidor público:
- Agregar **nginx** como reverse proxy (TLS termination, rate limiting, compression).
- Habilitar `SECURE_SSL_REDIRECT`, `HSTS`, `SECURE_CONTENT_TYPE_NOSNIFF` en `settings/production.py`.
- Rotar `SECRET_KEY` y contraseñas de BD periódicamente.
- Considerar `fail2ban` o rate limiting en la ruta `/api/v1/auth/login/`.

### Resumen de Hoja de Ruta de Escalabilidad

| Fase | Cambio | Beneficio |
|------|--------|-----------|
| Corto plazo | Redis para JWT blacklist y cache | Stateless real, rendimiento |
| Corto plazo | Nginx como reverse proxy | TLS, compresión, rate limiting |
| Mediano plazo | Django Channels + ASGI | Reemplaza polling, tiempo real |
| Mediano plazo | Celery para tareas programadas | Healthchecks automáticos |
| Largo plazo | Kubernetes / ECS | Alta disponibilidad, auto-scaling |
| Largo plazo | MySQL Replication + ProxySQL | Escala de BD para lectura |

---

## 12. Estado Actual del Proyecto

### Backend — Funcional

| Módulo | Estado |
|--------|--------|
| Autenticación JWT (login/refresh/logout) | ✅ Activo |
| Daily Events — crear / listar | ✅ Activo |
| Special Events — crear automáticamente al registrar evento en sitio especial | ✅ Activo |
| Special Events — listar / marcar | ✅ Activo |
| Timezone conversion UTC → hora local del sitio | ✅ Corregido |
| Healthcheck endpoint | ✅ Activo |
| OpenAPI / Swagger docs | ✅ Activo en `/api/schema/swagger-ui/` |
| Cover Requests | 🔄 En desarrollo |
| Reports | 🔄 En desarrollo |
| WebSockets | ⏳ Pendiente |
| Celery / tareas programadas | ⏳ Pendiente |

### Frontend — Funcional

| Módulo | Estado |
|--------|--------|
| Login con backend real (JWT) | ✅ Activo |
| Daily Events — tabla + crear evento | ✅ Activo |
| Special Events — tabla supervisor | ✅ Activo |
| Cover Requests | 🔄 En desarrollo |
| Dashboard Supervisor | 🔄 En desarrollo |
| Station Map | 🔄 En desarrollo |

---

## Referencias

- **Manual de usuario:** disponible en el equipo de supervisión (operación del sistema)
- **Guía de integración frontend-backend:** [`INTEGRATION_GUIDE.md`](./INTEGRATION_GUIDE.md)
- **Contexto de arquitectura:** [`ai/blueprints/architecture_overview.md`](./ai/blueprints/architecture_overview.md)
- **Decisiones de arquitectura (ADRs):** [`docs/architecture/decisions_log.md`](./docs/architecture/decisions_log.md)
- **Documentación de dominio:** [`docs/domain/`](./docs/domain/)
- **API OpenAPI/Swagger:** `http://localhost:8000/api/schema/swagger-ui/` (requiere backend activo)
