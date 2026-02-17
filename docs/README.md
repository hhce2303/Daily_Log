# Daily Log 2.0 - Sistema Web de Gestión para Central de Monitoreo

> **Sistema Enterprise de Registro y Supervisión de Operaciones**  
> Migración completa de aplicación desktop legacy a arquitectura web moderna.

---

## 📋 Descripción

Daily Log 2.0 es una aplicación web enterprise diseñada para gestionar operaciones en estaciones centrales de monitoreo de seguridad. Incluye registro de eventos diarios, gestión de coberturas, eventos especiales, auditoría operacional y visualización en tiempo real del workspace.

**Fase Actual:** Frontend funcional con mock data | Backend en desarrollo

---

## 🚀 Stack Tecnológico

### Frontend
- **Framework:** React 19.2.0 con Vite 7.3.1 (HMR ultrarrápido)
- **Lenguaje:** TypeScript 5.9.3 (strict mode)
- **Estilos:** TailwindCSS 3.4.4 (dark theme custom)
- **Tablas:** TanStack Table 8.21.3 (headless, type-safe)
- **Animaciones:** GSAP 3.14.2 (MagicBento component)
- **Routing:** React Context API (zero dependencies)

### Backend (Pendiente)
- **Framework:** Django REST Framework
- **Base de Datos:** MySQL (remote server)
- **Autenticación:** JWT + LDAP integration

---

## 🏗️ Arquitectura

**Modular Monolith** con estructura feature-based:
- Separación estricta de responsabilidades (SRP)
- Feature modules independientes (`/features/`)
- Capas: Presentation → Service → Domain → Data Access
- Preparada para evolucionar a microservicios sin refactoring estructural

Ver detalles completos en [`ai/blueprints/architecture_overview.md`](../ai/blueprints/architecture_overview.md)

---

## 🎭 Roles y Permisos

| Rol | Acceso |
|-----|--------|
| **Operador** | Daily Events, Cover Requests |
| **Supervisor** | Dashboard, Specials Events, Audit, Cover Time, Station Map |
| **Lead Supervisor** | Supervisor + gestión avanzada (futuro) |
| **Admin** | Acceso completo + configuración sistema (futuro) |

**Estado Actual:** Autenticación hardcoded (usuarios mock)  
Ver: `ADR-006` en [`docs/architecture/decisions_log.md`](architecture/decisions_log.md#adr-006)

---

## 📦 Módulos Implementados

### ✅ **Authentication** (`features/auth/`)
- Login con username/password
- Usuarios mock: `operador/1234`, `supervisor/4321`
- Role-based routing automático
- **TODOs:** Backend LDAP integration (ADR-003)

### ✅ **Daily Events** (`features/logs/`)
- Registro de eventos operacionales (Operador)
- 10 tipos de actividades: Cleaners, Detailers, Pickup Requests, etc.
- Tabla con sorting, pagination, inline editing (futuro)
- Mock data: 15 eventos hardcoded
- **TODOs:** Backend API, auto-save, START/END SHIFT

### ✅ **Cover Requests** (`features/covers/`)
- Solicitudes de cobertura (breaks, lunch, emergencias)
- Estados: pending, approved, rejected
- Tabla con status tracking
- Mock data: 10 cover requests
- **TODOs:** Supervisor approval workflow, notifications

### ✅ **Specials Events** (`features/specials/` - Supervisor)
- Eventos críticos escalados a supervisores
- 5 eventos mock (security incidents, equipment failures)
- Badges de prioridad (Baja/Media/Alta/Crítica) y estado (Pendiente/Enviado/Revisado)
- Asignación automática a supervisores
- **TODOs:** Approval/rejection actions, reassignment (ADR-008)

### ✅ **Audit Trail** (`features/audit/` - Supervisor)
- Registro completo de eventos operacionales (read-only)
- Filtros: Site, Date (Desde)
- 21 eventos mock con actividades variadas
- Tabla con 8 columnas: Fecha, Hora, Sitio, Actividad, Cantidad, Cámara, Descripción, Usuario
- **TODOs:** Advanced filters (date range, operator, activity type) (ADR-009)

### ✅ **Cover Time Audit** (`features/coverTime/` - Supervisor)
- Auditoría de tiempos de cobertura completados
- Filtros: Usuario, Desde, Hasta (date range)
- 20 covers mock con duraciones realistas (00:05:30 a 00:47:55)
- Color coding por motivo: Break (azul), Baño (amarillo), Lunch (verde), Emergencia (rojo)
- Tabla con 7 columnas: #, Usuario, Inicio Cover, Duración, Fin Cover, Cubierto por, Motivo
- **TODOs:** Statistics dashboard, export functionality (ADR-010)

### ✅ **Central Station Map** (`features/stationMap/` - Supervisor)
- Visualización SVG del workspace (1600x900, ~40 workstations)
- Dark theme con IDs únicos por workstation (WS_60, WS_62, etc.)
- Responsive container (16:9 aspect ratio)
- **Fase 1 (Actual):** Display-only estático
- **Fase 2 (Futuro):** WebSocket real-time updates, color coding por estado, click/hover interactivity, glow effect para alertas (ADR-011)
- Asset: `public/assets/maps/workspace_map.svg` (431 líneas)

---

## 🧭 Navegación

### Operador
```
Login → Daily Events ←→ Cover Requests
```

### Supervisor
```
Login → Supervisor Dashboard
         ├── Specials Events (approval queue)
         ├── Audit Trail (compliance view)
         ├── Cover Time (coverage analysis)
         └── Station Map (workspace monitoring)
```

**Componente:** PillNav animado (GSAP) en Topbar  
**Patrón:** Context-based navigation (ADR-005)

---

## 🎨 Componentes Destacados

### **MagicBento** (`shared/components/MagicBento/`)
Tarjetas animadas para Supervisor Dashboard:
- ✨ Particle effects con GSAP
- 🎯 Spotlight effect on hover
- 🌟 Star field background
- 💫 Border glow animation
- 🧲 Magnetic cursor interaction
- 📱 Click effect con scale
- **Implementación:** Custom, zero dependencies externas (ADR-007)

### **TanStack Table** (todos los módulos)
Tablas headless con:
- Type-safe columnas (TypeScript)
- Sorting multi-columna
- Pagination controlada
- Estados: loading, error, empty
- **Bundle:** ~40-50 kB (aceptable para funcionalidad) (ADR-004)

---

## 📐 Decisiones Arquitectónicas (ADRs)

| ADR | Decisión | Justificación |
|-----|----------|---------------|
| ADR-001 | Modular Monolith | Escalabilidad sin complejidad microservicios |
| ADR-002 | Two Repositories | `daily-log-frontend` + `daily-log-backend` |
| ADR-003 | Login tradicional | Simplicidad inicial, LDAP futuro |
| ADR-004 | TanStack Table v8 | Headless, type-safe, tree-shakeable |
| ADR-005 | Context-based routing | Zero deps, type-safe, controlado |
| ADR-006 | Mock auth hardcoded | Desarrollo frontend desacoplado |
| ADR-007 | Custom MagicBento | Zero deps, control total animaciones |
| ADR-008 | Specials Events module | Escalation queue para supervisores |
| ADR-009 | Audit Trail module | Compliance y supervisión general |
| ADR-010 | Cover Time module | Análisis productividad de coberturas |
| ADR-011 | Station Map module | Monitoring espacial workspace |

Ver decisiones completas: [`docs/architecture/decisions_log.md`](architecture/decisions_log.md)

---

## 🚦 Estado del Proyecto

### ✅ Implementado (Frontend)
- [x] Autenticación mock con 4 roles
- [x] Role-based routing (operador vs supervisor)
- [x] Daily Events (15 eventos mock)
- [x] Cover Requests (10 requests mock)
- [x] Specials Events (5 eventos escalados)
- [x] Audit Trail (21 eventos, filtros Site + Date)
- [x] Cover Time (20 covers, filtros User + Date Range)
- [x] Station Map (SVG workspace, 40 workstations)
- [x] MagicBento dashboard animations
- [x] Topbar PillNav navigation
- [x] Dark theme con TailwindCSS
- [x] TypeScript strict mode (0 compilation errors)
- [x] Network sharing configurado (Vite host: true)

### 🚧 Pendiente
- [ ] Backend Django REST Framework
- [ ] MySQL database integration
- [ ] LDAP authentication
- [ ] JWT token management
- [ ] WebSocket para Station Map real-time
- [ ] Supervisor approval workflows (Specials, Covers)
- [ ] START/END SHIFT logic
- [ ] Auto-save en Daily Events
- [ ] Export functionality (PDF, Excel)
- [ ] Advanced filtering (multi-column, date ranges)
- [ ] Push notifications
- [ ] Calendar integration (Covers)
- [ ] Statistics dashboards (Cover Time)

### 📊 Métricas
- **Archivos TypeScript:** ~30 módulos
- **Líneas de código:** ~3,500 (frontend)
- **Componentes:** 25+
- **Features modules:** 7
- **ADRs documentados:** 11
- **Mock data entries:** 81 eventos combinados
- **TypeScript errors:** 0
- **Bundle size (prod):** 334.18 kB (108.98 kB gzipped)

---

## 🛠️ Instalación y Ejecución

### Requisitos
- Node.js 18+ (recomendado: 20+)
- npm 9+

### Setup Local
```bash
# Clonar repositorio
git clone <repo-url>
cd daily-log-frontend/react-ts

# Instalar dependencias
npm install

# Ejecutar servidor de desarrollo
npm run dev

# Abrir en navegador
# Local: http://localhost:5173
# Network: http://192.168.101.135:5173 (tu IP local)
```

### Network Sharing (Testing)
La aplicación está configurada para ser accesible en la red local:

1. Asegúrate que tu firewall permite conexiones en el puerto 5173
2. Comparte la URL de Network con otros usuarios en la misma red WiFi/LAN
3. Usuarios de prueba:
   - **Operador:** `operador` / `1234`
   - **Supervisor:** `supervisor` / `4321`

**Configuración:** Vite config con `host: true` (ver `vite.config.ts`)

### Build para Producción
```bash
npm run build
# Output: dist/ (archivos estáticos optimizados)
```

---

## 📁 Estructura del Proyecto

```
daily-log-frontend/react-ts/
│
├── src/
│   ├── features/              # Módulos feature-based
│   │   ├── auth/              # Authentication
│   │   ├── logs/              # Daily Events
│   │   ├── covers/            # Cover Requests
│   │   ├── specials/          # Special Events (Supervisor)
│   │   ├── audit/             # Audit Trail (Supervisor)
│   │   ├── coverTime/         # Cover Time Audit (Supervisor)
│   │   └── stationMap/        # Central Station Map (Supervisor)
│   │
│   ├── pages/                 # Page components (routing endpoints)
│   ├── layouts/               # MainLayout wrapper
│   ├── shared/                # Componentes compartidos
│   │   └── components/        # MagicBento, PillNav, Topbar, Sidebar
│   │
│   ├── assets/                # Static assets
│   │   └── maps/              # SVG workspace map
│   │
│   ├── App.tsx                # Root + Context routing
│   ├── main.tsx               # Entry point
│   └── vite-env.d.ts          # Vite type declarations
│
├── public/
│   └── assets/maps/           # Public SVG assets (workspace_map.svg)
│
├── docs/                      # Documentación arquitectónica
│   └── architecture/
│       ├── decisions_log.md   # ADRs (11 decisiones)
│       └── module_structure.md # Feature modules detallados
│
├── ai/                        # AI context y blueprints
│   ├── blueprints/            # Arquitectura general
│   ├── context/               # Dependency policy, legacy context
│   └── skills/                # QA, backend, frontend, devops skills
│
├── vite.config.ts             # Vite configuration (host: true)
├── tailwind.config.js         # Dark theme custom
├── tsconfig.json              # TypeScript strict mode
└── package.json               # Dependencies
```

Ver estructura detallada: [`docs/architecture/module_structure.md`](architecture/module_structure.md)

---

## 📚 Documentación

### Arquitectura
- **Blueprint General:** [`ai/blueprints/daily_log_web_architecture_blueprint.md`](../ai/blueprints/daily_log_web_architecture_blueprint.md)
- **Overview Arquitectónico:** [`ai/blueprints/architecture_overview.md`](../ai/blueprints/architecture_overview.md)
- **Decisiones (ADRs):** [`docs/architecture/decisions_log.md`](architecture/decisions_log.md)
- **Estructura de Módulos:** [`docs/architecture/module_structure.md`](architecture/module_structure.md)

### Contexto
- **Dependency Policy:** [`ai/context/dependency_policy.md`](../ai/context/dependency_policy.md)
- **Legacy Desktop Context:** [`ai/context/legacy_desktop_functional_context.md`](../ai/context/legacy_desktop_functional_context.md)
- **Known Decisions:** [`ai/context/known_decisions.md`](../ai/context/known_decisions.md)
- **Technology Standards:** [`ai/context/technology_standards.md`](../ai/context/technology_standards.md)

### Skills (AI-Assisted Development)
- **QA Checklist:** [`ai/skills/qa.md`](../ai/skills/qa.md)
- **Backend Engineer:** [`ai/skills/backend_engineer.md`](../ai/skills/backend_engineer.md)
- **Frontend Engineer:** [`ai/skills/frontend_engineer.md`](../ai/skills/frontend_engineer.md)
- **DevOps:** [`ai/skills/devops.md`](../ai/skills/devops.md)

---

## 🔐 Seguridad

**Estado Actual (Development):**
- ⚠️ Autenticación hardcoded (NO producción)
- ⚠️ Sin JWT tokens
- ⚠️ Sin HTTPS
- ⚠️ Network sharing sin autenticación de red

**Roadmap de Seguridad (Producción):**
- [ ] JWT Authentication (Access + Refresh tokens)
- [ ] HTTPS obligatorio
- [ ] CORS restrictivo
- [ ] Rate limiting
- [ ] LDAP integration
- [ ] Audit logging completo
- [ ] Secure .env management
- [ ] Role-based permissions en backend

Ver: [`ai/blueprints/daily_log_web_architecture_blueprint.md`](../ai/blueprints/daily_log_web_architecture_blueprint.md#6️⃣-security-standards)

---

## 🧪 Testing

**Estado Actual:** Sin suite de testing implementada

**Roadmap:**
- [ ] Unit tests (Vitest)
- [ ] Component tests (React Testing Library)
- [ ] E2E tests (Playwright)
- [ ] Integration tests (API mocking)
- [ ] Visual regression tests

---

## 🚀 Roadmap

### Milestone 1: Frontend MVP ✅ **COMPLETADO**
- [x] Authentication mock
- [x] Daily Events module
- [x] Cover Requests module
- [x] Specials Events module (Supervisor)
- [x] Audit Trail module (Supervisor)
- [x] Cover Time module (Supervisor)
- [x] Station Map module (Supervisor)
- [x] MagicBento dashboard
- [x] Network sharing setup

### Milestone 2: Backend Integration 🚧 **EN PROGRESO**
- [ ] Django REST Framework setup
- [ ] MySQL database schema
- [ ] LDAP authentication
- [ ] JWT token endpoints
- [ ] API endpoints (logs, covers, specials, audit)
- [ ] WebSocket para Station Map

### Milestone 3: Production Readiness
- [ ] Testing suite completo
- [ ] CI/CD pipeline
- [ ] Docker containerization
- [ ] HTTPS + SSL certificates
- [ ] Monitoring y logging
- [ ] Error tracking (Sentry)
- [ ] Performance optimization

### Milestone 4: Advanced Features
- [ ] Supervisor approval workflows
- [ ] Push notifications
- [ ] Export functionality (PDF, Excel)
- [ ] Advanced analytics dashboards
- [ ] Calendar integration
- [ ] Mobile responsive optimizations

---

## 🤝 Contribución

Este proyecto sigue **Conventional Commits** para mensajes de commit.

### Workflow
1. `feature/*` → Nuevas características
2. `bugfix/*` → Correcciones de bugs
3. `hotfix/*` → Fixes críticos producción
4. `chore/*` → Mantenimiento general

### Pull Requests
- Código debe pasar TypeScript strict mode (0 errors)
- Seguir estructura feature-based
- Documentar decisiones arquitectónicas (ADRs) si aplica
- Actualizar `module_structure.md` para nuevos features

---

## 📞 Soporte

**Documentación Completa:** Ver carpetas `/docs` y `/ai`

**Preguntas Arquitectónicas:** Consultar ADRs en [`decisions_log.md`](architecture/decisions_log.md)

**Legacy Context:** Referirse a [`legacy_desktop_functional_context.md`](../ai/context/legacy_desktop_functional_context.md)

---

## 📄 Licencia

**Propietario:** SIG Systems, Inc.  
**Proyecto Interno:** Daily Log 2.0

---

**Última actualización:** Febrero 16, 2026  
**Versión:** 1.0.0 (Frontend MVP)  
**Estado:** ✅ Frontend funcional | 🚧 Backend en desarrollo
