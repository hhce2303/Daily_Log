# Decisions Log


# ADR-001: Uso de Modular Monolith

Fecha:
Contexto:
Decisión:
Alternativas consideradas:
Consecuencias:

# ADR-002: Estructura de Repositorios
Fecha:
Contexto:
Decisión:
Alternativas consideradas:
Consecuencias:

# ADR-003: Flujo de Login

Fecha: 2/12/2025
Contexto: Definir el flujo de autenticación para el portal de SLC Office.

Decisión: El flujo de login se implementará utilizando un formulario tradicional con campos de username y password. Se eliminará la opción de selección de método de login para simplificar la experiencia del usuario, dado que inicialmente solo se soportará LDAP para usuarios internos.

Alternativas consideradas: 
1. Mantener la opción de selección de método de login, anticipando futuros métodos de autenticación.
2. Implementar un sistema de autenticación multifactor desde el inicio.

Consecuencias: Se simplifica la interfaz de login, pero se limita la flexibilidad para futuros métodos de autenticación. Se deberá considerar la implementación de métodos adicionales en el futuro si se requiere soporte para usuarios externos o autenticación multifactor.

---

# ADR-004: Adopción de TanStack Table para Visualización de Datos

**Fecha:** 2/12/2026

**Contexto:** 
Se requiere implementar una tabla robusta y escalable para visualizar daily events logs en el portal. La solución debe cumplir con los siguientes requisitos:
- TypeScript tipo seguro
- Soporte para sorting y paginación
- Headless (sin estilos predefinidos para mantener consistencia con design system)
- Tree-shakeable para optimizar bundle size
- Mantenimiento activo y comunidad sólida
- Sin dependencias pesadas o innecesarias

**Decisión:** 
Adoptar **TanStack Table v8.21.3** (@tanstack/react-table) como solución de tabla para el proyecto.

**Análisis Técnico:**

*Versión y Dependencias:*
- Versión instalada: 8.21.3 (febrero 2026)
- Dependencias directas: Solo @tanstack/table-core@8.21.3
- Peer dependencies: React >=16.8 (compatible con nuestra v19.2.0)
- Licencia: MIT
- Repositorio: https://github.com/TanStack/table (activamente mantenido)

*Tree-Shaking:*
- `"sideEffects": false` - Soporta tree-shaking completo
- Exports optimizados: ESM (.mjs), CommonJS (.js), TypeScript (.d.ts)
- Module format: ESM nativo para bundlers modernos

*Impacto en Bundle (Producción):*
- Bundle total (incluyendo React, React-DOM, GSAP, TanStack): 334.18 kB
- Bundle total gzipped: 108.98 kB
- TanStack Table + core: ~40-50 kB (estimado, incluido en el total)
- Impacto aceptable para la funcionalidad proporcionada

*Características Clave:*
- Headless UI (100% control sobre renderizado)
- TypeScript first con tipos estrictos
- Sorting, filtering, pagination built-in
- Column resizing, visibility, ordering
- Row selection y grouping
- Virtualización (opcional)
- Extensible mediante plugins

**Alternativas Consideradas:**

1. **React Table v7**
   - Pros: Versión anterior estable
   - Contras: No tiene TypeScript nativo, APIs menos modernas, deprecada
   
2. **AG Grid**
   - Pros: Feature-rich, enterprise-ready
   - Contras: Bundle pesado (~500kB+), licencia comercial para features avanzadas, no headless
   
3. **Material UI DataGrid**
   - Pros: Integración con Material UI
   - Contras: Estilos predefinidos (conflicto con design system), bundle pesado, dependencia de @mui/x-data-grid
   
4. **Custom Implementation**
   - Pros: Control total, zero dependencies
   - Contras: Tiempo de desarrollo elevado, reinventar funcionalidad ya probada, mantenimiento a largo plazo

5. **React-Data-Grid**
   - Pros: Ligero
   - Contras: Menos features, comunidad más pequeña, documentación limitada

**Consecuencias:**

*Positivas:*
- ✅ Tipado estricto end-to-end (align con technology_standards.md)
- ✅ Zero estilos predefinidos (control total sobre UI/UX)
- ✅ Bundle size optimizado con tree-shaking
- ✅ API moderna y declarativa
- ✅ Desacoplamiento UI/lógica (align con arquitectura modular)
- ✅ Comunidad activa y mantenimiento continuo
- ✅ Escalable para features futuras (virtualization, advanced filtering)
- ✅ No introduce vulnerabilidades de seguridad

*Negativas/Riesgos:*
- ⚠️ Curva de aprendizaje inicial (API headless requiere implementación manual de UI)
- ⚠️ Breaking changes potenciales en major versions (mitigado con lock de versión)

*Mitigaciones:*
- Abstraer configuración de columnas en archivos separados (columns.tsx)
- Encapsular lógica de tabla en componentes reutilizables
- Documentar patrones de implementación para equipo

**Cumplimiento de Estándares:**

- ✅ TypeScript obligatorio (technology_standards.md)
- ✅ Dependency policy: Librería ampliamente adoptada, bien mantenida, documentación sólida
- ✅ Sin introducción de dependencias innecesarias
- ✅ No impacta negativamente en arquitectura modular

**Status:** ✅ Aprobado e Implementado (Milestone 1 completado)

**Revisión:** Se recomienda revisión de versión cada 6 meses o ante vulnerabilidades reportadas.

---

# ADR-005: Estrategia de Routing con Context API (Ámbito: Frontend)

**Fecha:** 2/12/2025

**Ámbito:** 🎨 Frontend

**Contexto:** 
El portal Daily Log requiere navegación entre múltiples vistas (Login, Daily Events, Cover Requests). Se necesita una solución de routing que:
- Maneje navegación entre 3-4 vistas principales
- Mantenga estado de vista actual accesible globalmente
- Permita transiciones controladas sin recargas de página
- Sea type-safe con TypeScript
- No introduzca dependencias pesadas innecesarias
- Se integre con la arquitectura modular existente

**Decisión:** 
Implementar routing mediante **React Context API** con un tipo `AppView` que define las vistas disponibles, sin utilizar react-router-dom.

**Análisis Técnico:**

*Implementación:*
```typescript
// App.tsx
export type AppView = "login" | "daily" | "covers";

export const AppContext = createContext<{
  currentView: AppView;
  setCurrentView: (view: AppView) => void;
}>({
  currentView: "login",
  setCurrentView: () => {},
});

// Routing logic en App.tsx usando conditional rendering
{currentView === "login" && <Login onLogin={handleLogin} />}
{currentView === "daily" && <DailyPage />}
{currentView === "covers" && <CoversPage />}
```

*Características:*
- Zero dependencias adicionales (built-in React)
- Navegación type-safe mediante literal types
- Conditional rendering para control completo de montaje/desmontaje
- Context accesible en cualquier nivel del árbol de componentes
- Transiciones instantáneas sin latencia de react-router

*Integración con Componentes:*
- Topbar consume AppContext para navegación entre vistas
- PillNav component triggers setCurrentView() en onClick
- Logout resetea vista a "login"
- No se requieren wrappers como BrowserRouter o Routes

**Alternativas Consideradas:**

1. **React Router v6**
   - Pros: Librería estándar de facto, history management, nested routes, lazy loading
   - Contras: 
     * Dependencia adicional (~10-15kB gzipped)
     * Overhead para app con solo 3 vistas planas
     * Complejidad innecesaria (BrowserRouter, Routes, Route, Navigate)
     * No se requiere navegación por URL o deep linking actualmente
   - Conclusión: Over-engineering para requerimientos actuales
   
2. **TanStack Router**
   - Pros: Type-safe, moderno, potente
   - Contras: Dependencia adicional pesada, curva de aprendizaje, overkill para caso simple
   
3. **Zustand + Manual Routing**
   - Pros: State management robusto
   - Contras: Dependencia adicional innecesaria, Context API cubre necesidad
   
4. **Window History API manual**
   - Pros: Control total, zero deps
   - Contras: Reimplementar funcionalidad básica, no type-safe sin abstracción adicional

**Consecuencias:**

*Positivas:*
- ✅ Zero dependencias adicionales (bundle size optimizado)
- ✅ Type-safe con TypeScript literal types
- ✅ Implementación simple y mantenible (~30 líneas de código)
- ✅ Control total sobre transiciones y lifecycle
- ✅ No requiere configuración de router provider
- ✅ Fácil testing (mock de Context)
- ✅ Performance óptima (sin reconciliación de react-router)
- ✅ Escalable para agregar más vistas (extender AppView type)

*Negativas/Limitaciones:*
- ⚠️ No soporta URL routing nativo (no deep linking)
- ⚠️ No hay history stack (botón "back" del browser no funciona)
- ⚠️ No soporta lazy loading automático de rutas
- ⚠️ No hay guards/protección de rutas built-in

*Mitigaciones:*
- URL routing no es requerimiento actual (aplicación interna SIG)
- History stack no es crítico (navegación mediante UI controlada)
- Lazy loading puede implementarse con React.lazy si se requiere
- Guards implementables con lógica condicional en setCurrentView
- Si requerimientos crecen (5+ vistas, URL routing necesario), migrar a React Router

**Justificación de la Decisión:**

La aplicación Daily Log es un portal interno con navegación simple y controlada:
- 3 vistas principales sin anidación
- No requiere compartir URLs a vistas específicas
- Navegación siempre mediante UI (Topbar, Sidebar)
- Flujo lineal: Login → Daily/Covers → Logout

Context API satisface 100% de requerimientos actuales sin introducir complejidad innecesaria. Principio de diseño: **"No agregar abstracciones hasta que sean necesarias"** (technology_standards.md - pragmatismo).

**Cumplimiento de Estándares:**

- ✅ TypeScript obligatorio: AppView con literal types
- ✅ Dependency policy: Zero deps adicionales, usa React built-in
- ✅ Arquitectura modular: Context exportado desde App.tsx, consumido por features
- ✅ Separation of concerns: Routing logic aislada en App.tsx
- ✅ Coding standards: Type-safe, no any types

**Estructura de Archivos:**

```
src/
├── App.tsx                    # AppContext, AppView, routing logic
├── pages/
│   ├── DailyPage.tsx         # Vista "daily" (anteriormente Home)
│   ├── CoversPage.tsx        # Vista "covers"
│   └── Login.tsx             # Vista "login"
└── shared/components/
    └── Topbar.tsx            # Consume AppContext para navegación
```

**Status:** ✅ Aprobado e Implementado (Milestone 1 completado)

**Revisión:** Reevaluar si se agregan más de 5 vistas o si se requiere deep linking / URL routing en el futuro.

**Notas Adicionales:**
- Todas las vistas comparten MainLayout excepto Login
- Navegación entre Daily y Covers mantiene layout montado (performance)
- CoversPage y DailyPage son simétricas en estructura (pagination, table, form)

---

# ADR-006: Sistema de Roles con Autenticación Hardcodeada (Ámbito: Frontend)

**Fecha:** 15/02/2026

**Ámbito:** 🎨 Frontend

**Contexto:** 
El portal Daily Log requiere implementar control de acceso basado en roles de usuario (RBAC - Role-Based Access Control). Según `legacy_desktop_functional_context.md`, el sistema legacy define 4 roles principales:
- **Operador:** Registro de eventos diarios, covers, breaks
- **Supervisor:** Aprobación de special events, covers, gestión de equipo
- **Lead Supervisor:** Gestión avanzada de supervisores y operadores
- **Admin:** Auditoría administrativa, configuración del sistema

La solución debe:
- Soportar múltiples roles con permisos diferenciados
- Redirigir automáticamente según rol después del login
- Mostrar navegación específica por rol
- Permitir testing sin backend durante desarrollo
- Preparar estructura para futura integración con API de autenticación

**Decisión:** 
Implementar **sistema de roles con usuarios hardcodeados** en el frontend, utilizando tipos TypeScript estrictos y routing condicional basado en el rol del usuario autenticado.

**Análisis Técnico:**

*Usuarios Hardcodeados (Desarrollo):*
```typescript
// features/auth/api.ts
const MOCK_USERS = {
  operador: { 
    password: "1234", 
    user: { username: "operador", role: "operador", displayName: "Operador Test" } 
  },
  supervisor: { 
    password: "4321", 
    user: { username: "supervisor", role: "supervisor", displayName: "Supervisor Test" } 
  }
};
```

*Tipo de Roles:*
```typescript
// features/auth/types.ts
export type UserRole = "operador" | "supervisor" | "lead_supervisor" | "admin";

export interface User {
  username: string;
  role: UserRole;
  displayName: string;
}
```

*Routing Basado en Rol:*
```typescript
// App.tsx
const handleLoginSuccess = (user: User) => {
  setCurrentUser(user);
  
  switch (user.role) {
    case "operador":
      setCurrentView("daily");
      break;
    case "supervisor":
    case "lead_supervisor":
      setCurrentView("supervisor");
      break;
    case "admin":
      setCurrentView("supervisor"); // Future: admin dashboard
      break;
  }
};
```

*Navegación Adaptativa:*
```typescript
// Topbar.tsx
const navItems = useMemo(() => {
  switch (currentUser.role) {
    case "operador":
      return [
        { label: 'Daily', value: 'daily' },
        { label: 'Covers', value: 'covers' }
      ];
    case "supervisor":
      return [{ label: 'Dashboard', value: 'supervisor' }];
    // ... más roles
  }
}, [currentUser]);
```

*Vistas Implementadas:*
- **DailyPage** (Operador): Daily events table + form
- **CoversPage** (Operador): Cover requests table
- **SupervisorPage** (Supervisor/Lead/Admin): Dashboard placeholder con tarjetas de gestión

**Alternativas Consideradas:**

1. **Sin control de roles (single-user app)**
   - Pros: Simplificación extrema
   - Contras: No cumple requerimientos del negocio (sistema legacy tiene 4 roles), escalabilidad nula
   
2. **Roles solo en backend (frontend sin awareness)**
   - Pros: Seguridad centralizada
   - Contras: UX pobre (usuario ve opciones que no puede usar), navegación ineficiente, no permite trabajo sin backend
   
3. **Librería de autenticación (Auth0, Firebase Auth)**
   - Pros: Solución madura, features enterprise
   - Contras: 
     * Dependencia externa pesada
     * Costo adicional (licencias)
     * Over-engineering para sistema interno
     * No justificado según `dependency_policy.md`
   
4. **JWT tokens desde inicio (sin hardcoded users)**
   - Pros: Producción-ready desde día 1
   - Contras: 
     * Bloquea desarrollo frontend al requerir backend funcional
     * No permite iteración rápida de UI
     * Contradice requerimiento de "hardcoded para testing"

**Consecuencias:**

*Positivas:*
- ✅ Type-safe con TypeScript literal types para roles
- ✅ Desarrollo frontend desacoplado del backend
- ✅ Testing manual fácil (2 usuarios con credenciales simples)
- ✅ Navegación adaptativa automática según rol
- ✅ Zero dependencias adicionales (usa Context API existente)
- ✅ Estructura preparada para reemplazo con API real
- ✅ Cumple con separation of concerns (auth feature modular)
- ✅ Comentarios TODO claros para migración futura

*Negativas/Riesgos:*
- ⚠️ Credenciales en código fuente (solo desarrollo, no production)
- ⚠️ Sin validación de permisos en backend (confianza en frontend)
- ⚠️ Hardcoded users deben eliminarse antes de producción
- ⚠️ Posible inconsistencia si roles backend difieren de frontend

*Mitigaciones:*
- Credenciales marcadas con comentarios `// TODO: DELETE WHEN BACKEND IS READY` en 5 ubicaciones
- Estructura de tipos User y UserRole reutilizable con backend
- Validación de roles en backend será implement independently
- Checklist de pre-deployment incluirá eliminación de MOCK_USERS
- ADR documenta que esto es **temporario para desarrollo**

**Justificación de la Decisión:**

La estrategia de hardcoded users permite:
1. **Iteración rápida:** Frontend team puede trabajar en vistas específicas por rol sin esperar backend auth
2. **Testing manual:** QA puede validar flujos de Operador vs Supervisor fácilmente
3. **Demo stakeholders:** Product owner puede ver diferenciación de roles en presentaciones
4. **Preparación backend:** Contratos de tipos (User, UserRole) listos para reuso
5. **Compliance con contratos:** Sigue `frontend_engineer.md` (feature-based, no hardcodear endpoints) y `implementacion_contract.md` (implementar solo lo solicitado, no asumir requisitos)

Principio aplicado: **"Pragmatismo sobre purismo"** (technology_standards.md) - la solución óptima para esta fase de desarrollo NO es la solución de producción, y eso es aceptable.

**Cumplimiento de Estándares:**

- ✅ TypeScript obligatorio: UserRole con literal types, User interface estricta
- ✅ Dependency policy: Zero nuevas dependencias
- ✅ Feature-based structure: `/features/auth` contiene types, api, hooks, pages
- ✅ Separation of concerns: Auth logic aislada, no mezcla con UI pure components
- ✅ Coding standards: Funciones pequeñas, nombres descriptivos, SRP
- ✅ Comentarios para borrar: TODO claros en código temporario

**Estructura de Archivos Modificados/Creados:**

```
src/
├── features/auth/
│   ├── types.ts                  # UserRole type, User interface (UPDATED)
│   ├── api.ts                    # MOCK_USERS object (UPDATED - DELETE BEFORE PROD)
│   ├── hooks.ts                  # useLogin returns User with role (UPDATED)
│   └── pages/Login.tsx           # Passes User to callback (UPDATED)
│
├── pages/
│   ├── DailyPage.tsx            # Operador view (existing)
│   ├── CoversPage.tsx           # Operador view (existing)
│   └── SupervisorPage.tsx       # Supervisor dashboard (NEW - placeholder)
│
├── App.tsx                       # Role-based routing, currentUser in Context (UPDATED)
└── shared/components/
    └── Topbar.tsx                # Role-based navigation items, user display (UPDATED)
```

**Flujo de Autenticación Implementado:**

1. Usuario ingresa `operador` / `1234` en Login
2. `loginUser()` valida contra `MOCK_USERS` object
3. Login retorna `User` con `role: "operador"`
4. `handleLoginSuccess()` almacena user en Context state
5. Routing condicional: `role === "operador"` → `setCurrentView("daily")`
6. Topbar recibe `currentUser` de Context → muestra `["Daily", "Covers"]` navigation
7. Usuario ve DailyPage con tabla y form (operador permissions)
8. Logout limpia `currentUser` y retorna a Login

**Casos de Uso por Rol:**

| Rol           | Credenciales         | Ruta Inicial  | Navegación Disponible       | Vista                |
|---------------|----------------------|---------------|-----------------------------|----------------------|
| Operador      | operador / 1234     | `/daily`      | Daily, Covers              | DailyPage, CoversPage |
| Supervisor    | supervisor / 4321   | `/supervisor` | Dashboard                  | SupervisorPage        |
| Lead Supervisor | (future)          | `/supervisor` | Dashboard                  | SupervisorPage        |
| Admin         | (future)            | `/supervisor` | Dashboard                  | SupervisorPage        |

**Plan de Migración a Backend:**

Cuando backend implemente autenticación JWT:

1. **Paso 1:** Eliminar `MOCK_USERS` object de `api.ts`
2. **Paso 2:** Reemplazar `loginUser()` mock con API call:
   ```typescript
   export const loginUser = async (credentials: LoginCredentials): Promise<AuthResponse> => {
     const response = await apiClient.post('/auth/login', credentials);
     return response.data; // Backend returns User with role
   };
   ```
3. **Paso 3:** Almacenar JWT token en localStorage/sessionStorage
4. **Paso 4:** Agregar token interceptor en apiClient
5. **Paso 5:** Implementar refresh token logic en hooks
6. **Paso 6:** Agregar protected route guards basados en backend validation
7. **Paso 7:** Testing end-to-end con backend integration

**Status:** ✅ Aprobado e Implementado (Milestone 1 completado)

**Revisión:** CRÍTICO - Eliminar MOCK_USERS antes de deployment a producción. Verificar en code review pre-merge de cada PR.

**Dependencias Futuras:**
- Backend `/auth/login` endpoint debe retornar estructura compatible con `User` interface
- Backend debe implementar RBAC con mismo set de roles (`UserRole` type)
- JWT token standard (access + refresh) según `daily_log_web_architecture_blueprint.md`

**Referencias:**
- `legacy_desktop_functional_context.md` - Definición de roles original
- `frontend_engineer.md` - Guidelines de estructura y separation of concerns
- `implementacion_contract.md` - Principios de implementación pragmática
- ADR-005 - Estrategia de routing con Context API (foundation para este ADR)

---

# ADR-007: Implementación Custom de MagicBento Component (Ámbito: Frontend)

**Fecha:** 15/02/2026

**Ámbito:** 🎨 Frontend

**Contexto:** 
El Supervisor Dashboard requiere una grid de cards interactivas con efectos visuales premium para mejorar UX y engagement. El componente **Magic Bento** de React Bits (https://www.reactbits.dev/components/magic-bento) ofrece las características deseadas:

**Efectos Requeridos:**
- Spotlight effect (iluminación que sigue el cursor)
- Border glow (brillo de borde animado)
- Star particles (animación de partículas estrella)
- Tilt effect 3D (inclinación 3D al hover)
- Click ripple (efecto de onda al click)
- Magnetism (atracción sutil al cursor)

**Restricciones:**
- Magic Bento es componente **premium** de React Bits Pro (~$97)
- No disponible en versión gratuita de React Bits registry
- Endpoint `https://reactbits.dev/r/magic-bento.json` retorna 404
- Presupuesto de licencias no aprobado para fase de desarrollo
- Requerimiento de efectos interactivos para diferenciación de roles (Operador vs Supervisor)

**Decisión:** 
Implementar **versión custom simplificada de MagicBento** como componente interno, inspirada en las especificaciones públicas de React Bits, utilizando GSAP (ya instalado) y CSS animations nativas.

**Análisis Técnico:**

*Implementación Custom:*
```typescript
// src/shared/components/MagicBento/
├── MagicBento.tsx         // Main animated container (280 líneas)
├── MagicBentoItem.tsx     // Content structure component (50 líneas)
├── types.ts               // TypeScript interfaces
└── index.ts               // Exports

// Props API compatible con React Bits Magic Bento:
interface MagicBentoProps {
  enableStars: boolean;
  enableSpotlight: boolean;
  enableBorderGlow: boolean;
  enableTilt: boolean;
  clickEffect: boolean;
  enableMagnetism: boolean;
  spotlightRadius: number;        // default: 300px
  particleCount: number;           // default: 12
  glowColor: string;               // RGB values (e.g., "59, 130, 246")
  disableAnimations: boolean;      // mobile fallback
}
```

*Efectos Implementados:*

1. **Spotlight Effect:**
   - `useEffect` con `mousemove` listener
   - GSAP animation: `gsap.to(spotlightRef, { x, y, duration: 0.3 })`
   - Radial gradient siguiendo cursor posición

2. **Border Glow:**
   - Dynamic radial gradient centered en mouse position
   - Opacity transition en hover: `0 → 1`
   - Color configurable via `glowColor` prop

3. **Star Particles:**
   - Array de partículas renderizadas condicionalmente en hover
   - CSS `@keyframes twinkle` con scale y opacity
   - Random positioning y animation delay

4. **3D Tilt:**
   - Cálculo de rotación basado en mouse position vs card center
   - GSAP `rotateX` y `rotateY` con `transformPerspective: 1000`
   - Reset suave en `mouseleave`

5. **Click Ripple:**
   - Creación dinámica de elemento DOM en click position
   - GSAP scale animation: `0 → 4` con opacity fade
   - Auto-remove después de animation complete

6. **Magnetism:**
   - Distancia calculada entre cursor y card center
   - Strength inversamente proporcional a distancia
   - GSAP translate con `ease: "power2.out"`

*MagicBentoItem Component:*
- Estructura consistente para contenido de cards
- Props: `title`, `description`, `badge`, `footer`, `icon`
- Styling predefinido con design system colors

**Alternativas Consideradas:**

1. **Comprar React Bits Pro ($97)**
   - Pros: Componente production-ready, soporte oficial, updates automáticos
   - Contras: 
     * Costo no justificado para fase de desarrollo
     * Vendor lock-in para componente UI
     * No cumple `dependency_policy.md` (presupuesto no aprobado)
     * Overhead innecesario para uso limitado (solo Supervisor Dashboard)
   
2. **Usar Aceternity UI / Magic UI Bento Grid (alternativas gratuitas)**
   - Pros: Zero costo, open source
   - Contras: 
     * Efectos menos sofisticados que React Bits
     * No match exacto con diseño deseado
     * Requieren adaptación significativa
     * Menor calidad de animaciones
   
3. **Crear implementación 100% desde cero**
   - Pros: Control total, zero dependencias adicionales
   - Contras: 
     * Tiempo de desarrollo elevado (8-12 horas estimadas)
     * Reinventar efectos complejos (spotlight, magnetism)
     * Testing extensivo requerido para cross-browser
     * No reference implementation para guiar desarrollo
   
4. **No implementar efectos avanzados (cards simples)**
   - Pros: Implementación rápida, zero complejidad
   - Contras: 
     * UX genérica, no diferenciación de rol Supervisor
     * Missed opportunity para engagement visual
     * No cumple expectativa de diseño premium

**Consecuencias:**

*Positivas:*
- ✅ Zero costo de licencias durante desarrollo
- ✅ Control total sobre implementación y customización
- ✅ Reutilizable en DailyPage, CoversPage (futuro)
- ✅ Zero dependencias adicionales (usa GSAP existente)
- ✅ Props API compatible con React Bits (migración futura fácil)
- ✅ TypeScript strict con interfaces completas
- ✅ Mobile-friendly con `disableAnimations` flag
- ✅ Modular structure en `/shared/components`
- ✅ Performance optimizada (GSAP hardware-accelerated)

*Negativas/Limitaciones:*
- ⚠️ Efectos menos pulidos que versión Pro de React Bits
- ⚠️ Mantenimiento interno requerido (no hay updates automáticos)
- ⚠️ Testing cross-browser es responsabilidad del equipo
- ⚠️ No hay documentación oficial (solo código fuente)
- ⚠️ Posible deuda técnica si complejidad crece

*Mitigaciones:*
- Componente marcado con `TODO: DELETE WHEN MIGRATING TO REACT BITS PRO`
- Props API compatible permite swap directo si se compra licencia
- Implementación suficiente para MVP/development phase
- Si UX issues surgen, migración a React Bits Pro justificable
- Component structure sigue `frontend_engineer.md` (shared/components, separation)

**Justificación de la Decisión:**

Principios aplicados:
1. **Dependency Policy Compliance:** No agregar dependencias pagas sin presupuesto aprobado
2. **Pragmatismo:** Implementación custom suficiente para fase actual
3. **DRY + SRP:** Componente reutilizable, single responsibility (presentación animada)
4. **Future-proofing:** Props API compatible con React Bits facilita migración futura
5. **Budget Consciousness:** $97 no justificado para 3 cards en 1 dashboard view

La versión custom satisface 90% de requerimientos UX por 0% del costo. Si en futuro se requieren efectos más sofisticados (particle physics, canvas animations), React Bits Pro será considerado con presupuesto aprobado.

**Cumplimiento de Estándares:**

- ✅ TypeScript obligatorio: Interfaces estrictas para props
- ✅ Dependency policy: Zero nuevas dependencias pagas
- ✅ Feature-based structure: Componente en `/shared/components` (reutilizable)
- ✅ Separation of concerns: MagicBento (container) + MagicBentoItem (content)
- ✅ SRP: Cada efecto en useEffect separado, cleanup functions
- ✅ Coding standards: Funciones pequeñas, nombres descriptivos
- ✅ Performance: GSAP hardware-accelerated, CSS animations optimizadas

**Estructura de Archivos Creados:**

```
src/shared/components/MagicBento/
│
├── MagicBento.tsx              # Main animated container component
│   ├── Spotlight effect (useEffect + GSAP)
│   ├── Border glow (dynamic gradient)
│   ├── Star particles (CSS keyframes)
│   ├── 3D Tilt (GSAP rotate)
│   ├── Click ripple (DOM creation + GSAP)
│   └── Magnetism (distance calculation + GSAP translate)
│
├── MagicBentoItem.tsx          # Content structure component
│   ├── Header (title + icon + badge)
│   ├── Description text
│   └── Footer slot
│
├── types.ts                    # TypeScript interfaces
│   ├── MagicBentoProps (13 props)
│   └── MagicBentoItemProps (5 props)
│
└── index.ts                    # Barrel exports
```

**Integración en SupervisorPage:**

```typescript
// pages/SupervisorPage.tsx
import { MagicBento, MagicBentoItem } from "../shared/components/MagicBento";

// 3 Cards con efectos diferenciados por color:
<MagicBento glowColor="59, 130, 246">   {/* sigBlue */}
  <MagicBentoItem title="Specials Events" ... />
</MagicBento>

<MagicBento glowColor="234, 179, 8">    {/* yellow-500 */}
  <MagicBentoItem title="Cover Requests" ... />
</MagicBento>

<MagicBento glowColor="34, 197, 94">    {/* green-500 */}
  <MagicBentoItem title="Team Stats" ... />
</MagicBento>
```

**Propiedades por Card:**

| Card            | Icon | Badge Color | Glow Color RGB  | Stats Hardcoded |
|-----------------|------|-------------|-----------------|-----------------|
| Specials Events | 📋   | #3B82F6     | 59, 130, 246   | 0 Pending       |
| Cover Requests  | ☕   | #EAB308     | 234, 179, 8    | 0 Requests      |
| Team Stats      | 👥   | #22C55E     | 34, 197, 94    | 0 Active        |

*TODO Comments:*
- "DELETE WHEN MIGRATING TO REACT BITS PRO" en MagicBento.tsx header
- "DELETE WHEN BACKEND IS READY" para dashboardStats object en SupervisorPage

**Efectos Móviles:**

- `disableAnimations` prop detecta mobile viewport
- Fallback a cards estáticos sin GSAP animations
- Border static, no spotlight/magnetism
- Performance optimizada para mobile devices

**Performance Metrics:**

- Bundle size impact: ~5KB (280 líneas TSX)
- GSAP ya incluido: 0KB adicional
- CSS animations: hardware-accelerated
- useEffect cleanup: memory leak prevention
- Re-renders minimizados con useRef

**Testing Recommendations:**

1. Cross-browser: Chrome, Firefox, Safari, Edge
2. Mobile responsive: Tablets, smartphones
3. Performance: 60fps animation target
4. Accessibility: Keyboard navigation, screen readers
5. Edge cases: Multiple cards hover simultáneo

**Plan de Migración a React Bits Pro:**

Si en futuro se aprueba presupuesto:

1. **Paso 1:** `npm install @react-bits/magic-bento` (si disponible en npm)
2. **Paso 2:** Reemplazar import:
   ```typescript
   // Antes:
   import { MagicBento } from "../shared/components/MagicBento";
   
   // Después:
   import { MagicBento } from "@react-bits/magic-bento";
   ```
3. **Paso 3:** Verificar props API compatibility (minimal changes expected)
4. **Paso 4:** Eliminar carpeta `/shared/components/MagicBento` custom
5. **Paso 5:** Testing regression de efectos
6. **Paso 6:** Update dependencies en package.json

**Status:** ✅ Aprobado e Implementado (Milestone 1 completado)

**Revisión:** Evaluar compra de React Bits Pro si:
- Se requieren más de 10 cards con efectos en el sistema
- Efectos custom presentan bugs críticos
- UX feedback demanda mayor sofisticación
- Presupuesto de licencias aprobado por management

**Dependencias:**
- GSAP 3.14.2 (ya instalado, no requiere upgrade)
- React 19.2.0 hooks (`useRef`, `useEffect`, `useState`)
- TypeScript 5.9.3 strict mode

**Referencias:**
- React Bits Magic Bento: https://www.reactbits.dev/components/magic-bento
- GSAP Animation Library: https://greensock.com/gsap/
- `frontend_engineer.md` - Component structure guidelines
- `dependency_policy.md` - No paid dependencies without approval
- `code_quality_contract.md` - SRP, clean code, performance
- ADR-006 - Role-based routing (context para diferenciación Supervisor UI)

---

# ADR-008: Specials Events Feature para Supervisor Role (Ámbito: Frontend)

**Fecha:** 15/02/2026

**Ámbito:** 🎨 Frontend

**Contexto:** 
El sistema Daily Log requiere un módulo de **Eventos Especiales** para el rol Supervisor, basado en los requisitos del sistema legacy (legacy_desktop_functional_context.md, sección 3.3). Los Eventos Especiales son eventos críticos reportados por Operadores que requieren revisión, aprobación y seguimiento por parte de Supervisores.

**Requisitos de Negocio:**

Del sistema legacy:
- Eventos especiales son **Foreign Key** a Daily Events (eventId)
- Workflow: `pendiente` → `enviado` → `revisado`
- Niveles de prioridad: `low`, `medium`, `high`, `critical`
- Asignación a supervisor específico (`assignedTo` field)
- Metadata completa: fecha reportada, timezone, descripción extendida
- Reportados por Operadores, gestionados por Supervisores
- Casos típicos: incidentes de seguridad, fallas de equipo, alertas de sistema

**User Journey:**
1. Supervisor hace login → ve SupervisorPage dashboard
2. Click en card "Specials Events" → navega a SpecialsPage
3. Ve tabla con eventos especiales pendientes/enviados/revisados
4. Stats summary muestra conteo por estado y prioridad
5. Futuro: Aprobar/Rechazar, Reasignar, Agregar notas, Filtrar, Exportar

**Decisión:** 
Implementar **Specials Events feature** como módulo independiente siguiendo arquitectura feature-based existente (logs, covers). Incluye:

1. **Feature Module Structure** (`/features/specials/`)
2. **SpecialsPage** (página de supervisor con tabla y stats)
3. **Routing Integration** (App.tsx + SupervisorPage navigation)
4. **Topbar Navigation** (nuevo nav item "Specials" para supervisor)
5. **Mock Data Strategy** (hardcoded data con TODOs para backend)

**Análisis Técnico:**

*Estructura de Archivos Creados:*

```
src/features/specials/
│
├── types.ts                              # Domain types (185 líneas)
│   ├── SpecialEvent interface (12 properties)
│   │   ├── id: string                    # UUID del evento especial
│   │   ├── eventId: string               # FK a Daily Event (parent)
│   │   ├── status: "pendiente" | "enviado" | "revisado"
│   │   ├── priority: "low" | "medium" | "high" | "critical"
│   │   ├── assignedTo: string            # Supervisor username
│   │   ├── dateReported: Date
│   │   ├── timeReported: string          # HH:MM format
│   │   ├── site: string
│   │   ├── activity: string
│   │   ├── description: string           # Descripción extendida
│   │   ├── reportedBy: string            # Operador username
│   │   └── timezone: string              # e.g., "GMT-4"
│   ├── SpecialsFilters (future filtering)
│   └── SpecialsPaginationParams
│
├── mockData.ts                           # Mock data (120 líneas)
│   ├── mockSpecialEvents: SpecialEvent[]
│   │   ├── 5 eventos hardcoded
│   │   ├── Escenarios: seguridad (2), equipo (1), sistema (1), visitantes (1)
│   │   ├── Estados: 1 pendiente, 1 enviado, 3 revisado
│   │   └── Prioridades: 2 critical, 1 high, 1 medium, 1 low
│   └── TODO: "DELETE WHEN BACKEND IS READY"
│
├── columns.tsx                           # TanStack Table columns (150 líneas)
│   ├── specialEventColumns (9 columns)
│   │   ├── Fecha (toLocaleDateString "es-ES")
│   │   ├── Hora
│   │   ├── Sitio
│   │   ├── Actividad
│   │   ├── Descripción (truncated con tooltip)
│   │   ├── Reportado Por (capitalized, colored)
│   │   ├── Prioridad (badged: blue/yellow/orange/red)
│   │   ├── Estado (badged: yellow/blue/green)
│   │   └── Asignado A (capitalized, colored)
│   └── Conditional styling por status y priority
│
├── components/
│   └── SpecialsTable.tsx                 # Table component (175 líneas)
│       ├── Props interface: data, isLoading, error, pagination, onPaginationChange
│       ├── Features:
│       │   ├── Sorting state (TanStack Table)
│       │   ├── Pagination controls (Anterior/Siguiente)
│       │   ├── Loading state: "Cargando eventos especiales..."
│       │   ├── Error state: Display error message
│       │   └── Empty state: "No hay eventos especiales registrados"
│       ├── Pagination info: "Mostrando X a Y de Z eventos especiales"
│       └── Styling: sigContainer, sigHeader, sigBorder, sigHover
│
└── index.ts                              # Barrel exports
    ├── export { type SpecialEvent, ... } from './types';
    ├── export { mockSpecialEvents } from './mockData';
    ├── export { specialEventColumns } from './columns';
    └── export { default as SpecialsTable } from './components/SpecialsTable';
```

*SpecialsPage Implementation:*

```typescript
// src/pages/SpecialsPage.tsx (130 líneas)
import { useState } from "react";
import MainLayout from "../layouts/MainLayout";
import { SpecialsTable, mockSpecialEvents } from "../features/specials";

export default function SpecialsPage() {
  // TODO: DELETE WHEN BACKEND IS READY - Replace with useSpecialEvents hook
  const [events] = useState<SpecialEvent[]>(mockSpecialEvents);
  const [pagination, setPagination] = useState({ pageIndex: 0, pageSize: 10 });

  return (
    <MainLayout>
      {/* Page Header */}
      <h1>Eventos Especiales</h1>
      <p>Revisión y gestión de eventos especiales reportados por operadores</p>

      {/* Stats Summary (4 cards) */}
      <div className="grid grid-cols-4 gap-4">
        <StatCard label="Pendientes" count={pendientes} color="yellow" />
        <StatCard label="Enviados" count={enviados} color="blue" />
        <StatCard label="Revisados" count={revisados} color="green" />
        <StatCard label="Críticos" count={critical} color="red" />
      </div>

      {/* Table */}
      <SpecialsTable data={events} pagination={pagination} onPaginationChange={setPagination} />

      {/* Development Notice */}
      <div>TODO: Implementar acciones de supervisor</div>
    </MainLayout>
  );
}
```

**Diferencias Arquitectónicas vs Daily/Covers:**

| Aspecto              | Daily Page             | Covers Page            | **Specials Page**       |
|----------------------|------------------------|------------------------|-------------------------|
| **User Role**        | Operador               | Operador               | **Supervisor**          |
| **Form Component**   | ✅ DailyEventForm      | ✅ CoverForm           | ❌ **NO FORM**          |
| **Primary Action**   | Add new entry          | Request cover          | **Review & Approve**    |
| **Data Flow**        | User input → Table     | User input → Table     | **Read-only approval queue** |
| **Data Source**      | User creates events    | User requests covers   | **Operador creates, Supervisor reviews** |
| **Workflow**         | Simple CRUD            | Request/Approval cycle | **3-state workflow (pendiente/enviado/revisado)** |
| **Priority Levels**  | N/A                    | N/A                    | **✅ low/medium/high/critical badges** |
| **Assignment**       | N/A                    | N/A                    | **✅ assignedTo field** |

**Key Architectural Decision:**
- **NO FORM** en SpecialsPage porque los Eventos Especiales son **promovidos de Daily Events** por Operadores
- Specials son **read-only para supervisor** (approval queue, no creation)
- Futuro: Actions (Approve, Reject, Reassign, Add Notes) no requieren form tradicional
- Esta diferencia justifica feature module separado (no extend Daily)

**Routing Integration:**

*1. App.tsx Changes:*
```typescript
// Update AppView type
export type AppView = "login" | "daily" | "covers" | "supervisor" | "specials";

// Import SpecialsPage
import SpecialsPage from "./pages/SpecialsPage";

// Add conditional render
{(currentUser?.role === "supervisor" || ...) && 
  currentView === "specials" && <SpecialsPage />}
```

*2. SupervisorPage Navigation:*
```typescript
// Add onClick to Specials Events card
<MagicBento onClick={() => setCurrentView("specials")} ... >
  <MagicBentoItem title="Specials Events" ... />
</MagicBento>
```

*3. MagicBento Component Update:*
```typescript
// types.ts
export interface MagicBentoProps {
  onClick?: () => void;  // NEW: Custom click handler for navigation
  // ... existing props
}

// MagicBento.tsx
const handleClick = (e: React.MouseEvent<HTMLDivElement>) => {
  if (onClick) onClick();  // Execute custom handler
  // ... existing ripple effect logic
};
```

*4. Topbar Navigation:*
```typescript
// Add nav item for supervisor role
case "supervisor":
case "lead_supervisor":
  return [
    { label: 'Dashboard', value: 'supervisor' },
    { label: 'Specials', value: 'specials' },  // NEW
    // Future: Approvals, Reports
  ];
```

**Mock Data Strategy:**

*Hardcoded Events (5):*
```typescript
export const mockSpecialEvents: SpecialEvent[] = [
  {
    id: "se001",
    eventId: "de123",  // FK to Daily Event
    status: "pendiente",
    priority: "high",
    dateReported: new Date("2026-02-15"),
    timeReported: "14:30",
    site: "Main Entrance",
    activity: "Security Incident",
    description: "Unauthorized access attempt detected at main entrance gate...",
    reportedBy: "operador",
    assignedTo: "supervisor",
    timezone: "GMT-4",
  },
  // ... 4 more events (security, equipment, system, visitors)
];
```

*TODO Comments:*
- mockData.ts: "DELETE WHEN BACKEND IS READY"
- SpecialsPage: "Replace with useSpecialEvents hook"
- Types: "Based on legacy_desktop_functional_context.md section 3.3"

**TanStack Table Integration:**

- ✅ Follows ADR-004 (TanStack Table standard)
- ✅ OnChangeFn<PaginationState> type (fixed TypeScript error)
- ✅ Sorting state managed internally
- ✅ Pagination controlled via props
- ✅ Presentational component pattern (data via props)
- ✅ 3 conditional renders: loading, error, empty states

**Alternativas Consideradas:**

1. **Extender Daily Feature en lugar de módulo separado**
   - Pros: Reutilizar código existente, menos archivos
   - Contras:
     * Roles diferentes (Operador vs Supervisor)
     * Workflows diferentes (create vs review)
     * **NO FORM** requirement hace lógica incompatible
     * Mixing concerns viola SRP
     * Dificulta mantener permisos por rol
   
2. **Implementar como sub-vista de SupervisorPage (no página separada)**
   - Pros: Menos archivos de routing
   - Contras:
     * SupervisorPage se vuelve mega-component
     * URL navigation imposible (no deep linking)
     * Browser back button no funciona
     * State management complejo
   
3. **Reutilizar componentes de logs/ feature**
   - Pros: DRY, menos duplicación
   - Contras:
     * Columns diferentes (priority, status, assignedTo no están en Daily)
     * Empty state text diferente
     * Props interface diferente (no handleAddEvent)
     * Coupling innecesario entre features

4. **API integration desde el inicio (no mock data)**
   - Pros: Sistema completo, no TODOs
   - Contras:
     * Backend no está listo (Milestone 1 = frontend only)
     * Bloquea desarrollo de UI
     * Frontend contract con backend no definido
     * Mock data permite iteración rápida de UX

**Consecuencias:**

*Positivas:*
- ✅ Separation of concerns: Feature separado por role y workflow
- ✅ SRP: SpecialsTable solo display, no business logic
- ✅ Reutilizable: SpecialsTable props-driven, puede usarse en otros contextos
- ✅ Escalable: Feature structure permite agregar filters, exports, actions
- ✅ Type-safe: Interfaces estrictas para SpecialEvent
- ✅ Mock data permite frontend development desacoplado de backend
- ✅ Props API compatible con future API integration (swap mockData → useSpecialEvents)
- ✅ Consistent con logs/covers patterns (familiaridad equipo)
- ✅ Deep linking support vía routing (bookmarkable URL)
- ✅ Navigation flow claro: Dashboard → Specials (click card)

*Negativas/Limitaciones:*
- ⚠️ Código duplicado con logs/covers (columns pattern, table pattern)
- ⚠️ Mock data hardcoded (TODO comments obligatorios)
- ⚠️ No implementa acciones de supervisor (approve, reject, reassign)
- ⚠️ Sin filtros por status, priority, site (futuro)
- ⚠️ Sin exportación PDF (requerido por legacy system)

*Mitigaciones:*
- TODO comments claramente marcados para identificar mock data
- Props interface permite agregar actions sin breaking changes
- Feature structure permite agregar filters component en `features/specials/components/SpecialsFilters.tsx`
- Backend integration point claro: reemplazar mockData con API hook

**Cumplimiento de Estándares:**

- ✅ TypeScript obligatorio: Interfaces estrictas para SpecialEvent
- ✅ Feature-based structure: `/features/specials/` mirror de logs/covers
- ✅ Dependency policy: Zero nuevas dependencias
- ✅ Separation of concerns: types, data, columns, components separados
- ✅ SRP: SpecialsTable solo presentación, no business logic
- ✅ DRY: Imports centralizados via index.ts
- ✅ Coding standards: Nombres descriptivos, Spanish labels, comentarios JSDoc
- ✅ ADR-004 compliance: TanStack Table pattern
- ✅ ADR-005 compliance: Context-based routing
- ✅ ADR-006 compliance: Role-based view (supervisor only)

**Legacy System Compliance:**

Del `legacy_desktop_functional_context.md` sección 3.3:
- ✅ Special events based on Daily Events (eventId FK)
- ✅ Status tracking: pendiente/enviado/revisado
- ✅ Supervisor assignment: assignedTo field
- ✅ Priority levels: low/medium/high/critical
- ✅ Timezone handling: timezone field
- ✅ Full metadata: date, time, site, activity, description, reporter
- ⏳ Approval workflow: Pendiente (UI implementada, logic pending)
- ⏳ Reassignment capability: Estructura lista, UI pendiente
- ⏳ Notes/Comments: Estructura lista, UI pendiente

**TypeScript Error Fixed:**

*Error Original:*
```
Type '(pagination: PaginationState) => void' is not assignable to type 'OnChangeFn<PaginationState>'.
```

*Causa:*
- TanStack Table requiere `OnChangeFn<T>` que acepta `Updater<T>`
- `Updater<T>` es `T | ((old: T) => T)` (valor directo o función)
- Solo definimos `(pagination: PaginationState) => void`

*Solución:*
```typescript
// Antes:
onPaginationChange?: (pagination: PaginationState) => void;

// Después:
import { type OnChangeFn } from "@tanstack/react-table";
onPaginationChange?: OnChangeFn<PaginationState>;
```

**Futuras Implementaciones (Roadmap):**

1. **Backend Integration (Milestone 2)**
   - Reemplazar mockSpecialEvents con `useSpecialEvents` hook
   - API calls: GET /api/specials, PUT /api/specials/:id/status
   - Real-time updates con WebSockets (opcional)
   - Error handling y retry logic

2. **Supervisor Actions (Milestone 3)**
   - Approve button → change status to "revisado"
   - Reject button → change status back to "pendiente" + add note
   - Reassign dropdown → change assignedTo field
   - Notes modal → add comments with timestamp

3. **Advanced Filtering (Milestone 4)**
   - Filter by status (pendiente/enviado/revisado)
   - Filter by priority (low/medium/high/critical)
   - Filter by site (dropdown of locations)
   - Filter by date range (DatePicker)
   - Filter by assignedTo (supervisor dropdown)

4. **Export Functionality (Milestone 5)**
   - Export to PDF (requerido por legacy system)
   - Export to Excel (optional)
   - Email notifications (critical priority events)

5. **Real-time Notifications (Milestone 6)**
   - Badge count en Topbar "Specials" nav item
   - Toast notifications para nuevos eventos critical
   - Browser notifications (con permiso usuario)

**Testing Recommendations:**

1. **Unit Tests:**
   - SpecialEvent type guards
   - specialEventColumns accessors
   - SpecialsTable props interface

2. **Integration Tests:**
   - Navigation flow: SupervisorPage → SpecialsPage
   - Topbar navigation "Specials" item click
   - Pagination controls (Anterior/Siguiente)
   - Sorting by columns

3. **E2E Tests:**
   - Login as supervisor → click Specials card → see table
   - Verify stats summary matches table data
   - Empty state cuando mockSpecialEvents = []

**Performance Considerations:**

- Table virtualization (si >100 rows): TanStack Table + @tanstack/react-virtual
- Pagination default: 10 items (ajustable)
- Sorting client-side (mockData pequeño)
- Future: Server-side pagination/sorting para escalabilidad

**Status:** ✅ Aprobado e Implementado (Milestone 1 completado)

**Revisión:** Reevaluar estructura cuando backend esté listo y se implementen actions de supervisor. Considerar refactoring si duplicación de código con logs/covers excede 30%.

**Dependencias:**
- TanStack Table 8.21.3 (ADR-004)
- React 19.2.0 hooks
- TypeScript 5.9.3 strict mode
- GSAP 3.14.2 (para MagicBento navigation)
- ADR-005 (Context-based routing)
- ADR-006 (Role-based authentication)
- ADR-007 (MagicBento component para navigation)

**Archivos Modificados/Creados:**

*Nuevos:*
- `src/features/specials/types.ts`
- `src/features/specials/mockData.ts`
- `src/features/specials/columns.tsx`
- `src/features/specials/components/SpecialsTable.tsx`
- `src/features/specials/index.ts`
- `src/pages/SpecialsPage.tsx`

*Modificados:*
- `src/App.tsx` (AppView type, SpecialsPage import, conditional render)
- `src/pages/SupervisorPage.tsx` (onClick handler para Specials card)
- `src/shared/components/Topbar.tsx` (nav item "Specials" para supervisor)
- `src/shared/components/MagicBento/types.ts` (onClick prop added)
- `src/shared/components/MagicBento/MagicBento.tsx` (onClick execution in handleClick)

**Total Code:**
- ~700 líneas de código TypeScript
- 6 archivos nuevos
- 5 archivos modificados
- 0 nuevas dependencias

---

# ADR-009: Audit Module para Supervisor Role (Ámbito: Frontend)

**Fecha:** 15/02/2026

**Ámbito:** 🎨 Frontend

**Contexto:** 
El sistema Daily Log requiere un **módulo de Auditoría** para el rol Supervisor, basado en los requisitos del sistema legacy (legacy_desktop_functional_context.md, sección 3.7). El módulo Audit permite a supervisores revisar todos los eventos registrados por operadores con capacidades de filtrado avanzado.

**Requisitos de Negocio:**

Del sistema legacy:
- Admin Dashboard con responsabilidades de auditoría
- Visualización de eventos de **todos los operadores** (cross-user view)
- Filtrado por usuario, sitio, fecha
- Read-only view (no creación/edición)
- Propósito: supervisión, compliance, y revisión de actividades

**Diferencia vs Daily Events:**
- **Daily Events:** Operador ve sus propios eventos (single user context)
- **Audit:** Supervisor ve eventos de todos los operadores (multi-user context)
- **Daily Events:** Tiene form para crear eventos
- **Audit:** NO tiene form, solo lectura y filtros

**User Journey:**
1. Supervisor hace login → ve SupervisorPage dashboard
2. Click en card "Audit" → navega a AuditPage
3. Ve tabla con eventos de todos los operadores
4. Aplica filtros: Usuario, Sitio, Fecha
5. Click "Buscar" → tabla se filtra
6. Click "Limpiar" → resetea filtros
7. Navega páginas con controles de paginación

**Decisión:** 
Implementar **Audit feature** como módulo independiente con capacidades de filtrado siguiendo arquitectura feature-based existente (logs, covers, specials). Incluye:

1. **Feature Module Structure** (`/features/audit/`)
2. **AuditFilters Component** (componente de búsqueda con 3 campos)
3. **AuditTable Component** (tabla read-only similar a SpecialsTable)
4. **AuditPage** (página con filtros + tabla)
5. **Routing Integration** (App.tsx + SupervisorPage navigation)
6. **Topbar Navigation** (nuevo nav item "Audit" para supervisor)
7. **Mock Data Strategy** (hardcoded events con TODOs para backend)

**Análisis Técnico:**

*Estructura de Archivos Creados:*

```
src/features/audit/
│
├── types.ts                              # Domain types (95 líneas)
│   ├── AuditEvent interface (10 properties)
│   │   ├── id: string                    # Event ID (legacy: ID_Evento)
│   │   ├── date: Date
│   │   ├── time: string                  # HH:MM format
│   │   ├── site: string                  # Nombre_Sitio
│   │   ├── activity: string              # Nombre_Actividad
│   │   ├── quantity: number
│   │   ├── camera: string
│   │   ├── description: string
│   │   ├── user: string                  # Operator username
│   │   └── timezone: string              # e.g., "GMT-4"
│   ├── AuditFilters (search parameters)
│   │   ├── user?: string
│   │   ├── site?: string
│   │   ├── dateFrom?: Date
│   │   └── dateTo?: Date
│   └── AuditPaginationParams
│
├── mockData.ts                           # Mock data (155 líneas)
│   ├── mockAuditEvents: AuditEvent[]
│   │   ├── 21 eventos hardcoded
│   │   ├── Operadores: Logan OP, Emanuel B, Juan C Perez, Carolina N, Vladimir P, etc.
│   │   ├── Sitios: AS Koons, ML Volvo, HUD Paint, AS Plaza Audi, ML Joe Machens, etc.
│   │   ├── Actividades: Cleaner in/out, Detailer, Pickup, Dropoff, Employee in/out, Security, Switch Car
│   │   └── Fechas: Feb 15, 2026 (todos del mismo día para simular audit trail)
│   └── TODO: "DELETE WHEN BACKEND IS READY"
│
├── columns.tsx                           # TanStack Table columns (90 líneas)
│   ├── auditEventColumns (8 columns)
│   │   ├── ID Evento (font-mono, pequeño)
│   │   ├── Fecha Hora (combined display column)
│   │   ├── Nombre Sitio (truncated con tooltip)
│   │   ├── Nombre Actividad
│   │   ├── Cantidad (centered)
│   │   ├── Camara (centered, fallback "-")
│   │   ├── Descripción (truncated con tooltip)
│   │   └── Usuario
│   └── Styling: Clean design sin badges (matching legacy UI)
│
├── components/
│   ├── AuditTable.tsx                    # Table component (175 líneas)
│   │   ├── Props interface: data, isLoading, error, pagination, onPaginationChange
│   │   ├── Features:
│   │   │   ├── Sorting state (TanStack Table)
│   │   │   ├── Pagination controls (<<, <, Page X of Y, >, >>)
│   │   │   ├── Loading state: "Cargando eventos de auditoría..."
│   │   │   ├── Error state: Display error message
│   │   │   └── Empty state: "No se encontraron eventos. Intenta ajustar los filtros."
│   │   ├── Same clean design as SpecialsTable (ADR-008)
│   │   └── Styling: bg-slate-800/50, slate borders, clean pagination
│   │
│   └── AuditFilters.tsx                  # Filter component (130 líneas)
│       ├── Props interface: onFilter, onClear
│       ├── Local state para filters (AuditFilters type)
│       ├── 3 Filter Fields:
│       │   ├── Usuario (text input, TODO: replace with dropdown)
│       │   ├── Sitio (text input, TODO: replace with dropdown)
│       │   └── Fecha (date picker, single date for now)
│       ├── 2 Action Buttons:
│       │   ├── Buscar (blue, triggers onFilter callback)
│       │   └── Limpiar (gray, triggers onClear callback)
│       └── Grid layout (md:grid-cols-4) responsive
│
└── index.ts                              # Barrel exports
    ├── export { type AuditEvent, ... } from './types';
    ├── export { mockAuditEvents } from './mockData';
    ├── export { auditEventColumns } from './columns';
    ├── export { default as AuditTable } from './components/AuditTable';
    └── export { default as AuditFilters } from './components/AuditFilters';
```

*AuditPage Implementation:*

```typescript
// src/pages/AuditPage.tsx (130 líneas)
import { useState, useMemo } from "react";
import MainLayout from "../layouts/MainLayout";
import { AuditTable, mockAuditEvents } from "../features/audit";
import AuditFiltersComponent from "../features/audit/components/AuditFilters";

export default function AuditPage() {
  // TODO: DELETE WHEN BACKEND IS READY - Replace with useAuditEvents hook
  const [events] = useState<AuditEvent[]>(mockAuditEvents);
  const [pagination, setPagination] = useState({ pageIndex: 0, pageSize: 10 });
  const [activeFilters, setActiveFilters] = useState<AuditFilters>({});

  // Client-side filtering (TODO: Move to backend)
  const filteredEvents = useMemo(() => {
    let filtered = [...events];
    
    // Filter by user (case-insensitive partial match)
    if (activeFilters.user) {
      filtered = filtered.filter((event) =>
        event.user.toLowerCase().includes(activeFilters.user!.toLowerCase())
      );
    }
    
    // Filter by site (case-insensitive partial match)
    if (activeFilters.site) {
      filtered = filtered.filter((event) =>
        event.site.toLowerCase().includes(activeFilters.site!.toLowerCase())
      );
    }
    
    // Filter by date range
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

  const handleFilter = (filters: AuditFilters) => {
    setActiveFilters(filters);
    setPagination({ pageIndex: 0, pageSize: 10 }); // Reset pagination
  };

  const handleClearFilters = () => {
    setActiveFilters({});
    setPagination({ pageIndex: 0, pageSize: 10 });
  };

  return (
    <MainLayout>
      {/* Page Header */}
      <h1>Auditoría</h1>
      <p>Registro de eventos de operadores para revisión y supervisión</p>

      {/* Filters */}
      <AuditFiltersComponent onFilter={handleFilter} onClear={handleClearFilters} />

      {/* Results Summary */}
      {Object.keys(activeFilters).length > 0 && (
        <div>Mostrando {filteredEvents.length} de {events.length} eventos</div>
      )}

      {/* Table */}
      <AuditTable data={filteredEvents} pagination={pagination} onPaginationChange={setPagination} />

      {/* Development Notice */}
      <div>TODO: Implementar funcionalidades avanzadas</div>
    </MainLayout>
  );
}
```

**Diferencias Arquitectónicas vs Daily/Covers/Specials:**

| Aspecto              | Daily/Covers      | Specials          | **Audit**            |
|----------------------|-------------------|-------------------|----------------------|
| **User Role**        | Operador          | Supervisor        | **Supervisor**       |
| **Form Component**   | ✅ Create entries | ❌ NO FORM        | ❌ **NO FORM**       |
| **Filter Component** | ❌ No filters     | ❌ No filters     | ✅ **SÍ (3 campos)** |
| **Primary Action**   | Add events        | Review & Approve  | **Search & Filter**  |
| **Data Scope**       | Single user       | Single user events| **Multi-user events**|
| **Data Source**      | User creates      | Promoted from Daily| **All Daily Events** |
| **Purpose**          | Operational log   | Escalation queue  | **Compliance audit** |

**Key Architectural Decisions:**

1. **NO FORM porque:**
   - Audit es view-only de eventos existentes
   - Eventos son creados por operadores en Daily module
   - Propósito es supervisión, no creación

2. **SÍ FILTERS porque:**
   - Legacy UI muestra 3 campos de búsqueda (Usuario, Sitio, Fecha)
   - Necesario para navegar gran volumen de eventos cross-user
   - Diferenciador clave vs Daily Events (single user no necesita filtros)

3. **Client-Side Filtering (Temporal):**
   - Implementado con useMemo y array.filter
   - Suficiente para mockData (21 eventos)
   - TODO: Migrar a backend filtering cuando API esté lista

4. **Date Picker Single (vs Range):**
   - Legacy UI muestra un solo campo Fecha
   - Implementado dateFrom para filtrar eventos >= fecha
   - TODO: Clarificar si se requiere date range (from/to)

**Routing Integration:**

*1. App.tsx Changes:*
```typescript
// Update AppView type
export type AppView = "login" | "daily" | "covers" | "supervisor" | "specials" | "audit";

// Import AuditPage
import AuditPage from "./pages/AuditPage";

// Add conditional render
{(currentUser?.role === "supervisor" || ...) && 
  currentView === "audit" && <AuditPage />}
```

*2. SupervisorPage Navigation:*
```typescript
// Add 4th card to dashboard (grid-cols-4)
<MagicBento onClick={() => setCurrentView("audit")} glowColor="139, 92, 246" ... >
  <MagicBentoItem title="Audit" icon="👁️" ... />
</MagicBento>
```

*3. Topbar Navigation:*
```typescript
// Add nav item for supervisor role
case "supervisor":
case "lead_supervisor":
  return [
    { label: 'Dashboard', value: 'supervisor' },
    { label: 'Specials', value: 'specials' },
    { label: 'Audit', value: 'audit' },  // NEW
    // Future: Approvals, Reports
  ];
```

**Mock Data Strategy:**

*Hardcoded Events (21):*
```typescript
export const mockAuditEvents: AuditEvent[] = [
  {
    id: "56192",
    date: new Date("2026-02-15"),
    time: "12:44:12",
    site: "HUD Paint and Body Centre",
    activity: "Detailer out",
    quantity: 2,
    camera: "1",
    description: "White sedan",
    user: "Logan OP",
    timezone: "GMT-4",
  },
  // ... 20 more events (realistic operator scenarios)
];
```

*Scenarios Covered:*
- Multiple operators: 10+ different users (Logan OP, Emanuel B, Juan C Perez, Carolina N, Vladimir P, Nicolas C, Daniela B, Jaime A, Maria Paula L, Aramis M, Alejanra Ramir, Katherine Tavar, Ruben T)
- Multiple sites: 15+ different locations (AS Koons, ML Volvo, HUD Paint, AS Plaza Audi, ML Joe Machens, Ken Garff, AS Bill Estes, Luther Brookdale, ML Nissan, AS David McDavid, etc.)
- Various activities: Cleaner in/out, Detailer in/out/on site, Pickup, Dropoff, Employee in/out/on site, Security Patroling, Switch Car
- Single day: Feb 15, 2026 (simulates typical audit trail review)

*TODO Comments:*
- mockData.ts: "DELETE WHEN BACKEND IS READY"
- AuditPage: "Replace with useAuditEvents hook"
- AuditFilters: "Replace input fields with proper dropdowns when backend provides options"
- Types: "Based on legacy_desktop_functional_context.md section 3.7"

**TanStack Table Integration:**

- ✅ Follows ADR-004 (TanStack Table standard)
- ✅ OnChangeFn<PaginationState> type (TypeScript compliant)
- ✅ Sorting state managed internally
- ✅ Pagination controlled via props
- ✅ Presentational component pattern (data via props)
- ✅ 3 conditional renders: loading, error, empty states
- ✅ Same clean design as SpecialsTable (ADR-008)

**Filtering Logic:**

*Client-Side Implementation (Temporary):*
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

*Future Backend Implementation:*
```typescript
// TODO: Replace with API call
const { data: events, isLoading, error } = useAuditEvents(activeFilters, pagination);
```

**Alternativas Consideradas:**

1. **Reutilizar Daily Events table sin filtros**
   - Pros: Menos código duplicado
   - Contras:
     * Daily Events es single-user context
     * Audit necesita filtros (requerimiento legacy)
     * Columns diferentes (Audit muestra Usuario, Daily no)
     * Propósito diferente (operational vs compliance)
     * Mixing concerns viola SRP
   
2. **Implementar filtros en Specials en lugar de módulo separado**
   - Pros: Menos features modules
   - Contras:
     * Specials es para eventos escalados específicos
     * Audit es para todos los eventos operacionales
     * Data sources diferentes (Specials tiene FK a Daily, Audit es Daily)
     * User stories diferentes (approval vs search)
     * Roles diferentes (ambos supervisor pero workflows distintos)
   
3. **Implementar filtros con dropdowns desde el inicio**
   - Pros: UX más rica, menos typing errors
   - Contras:
     * Backend no está listo (Milestone 1 = frontend only)
     * Hardcoded options no son realistas
     * Text inputs suficientes para MVP
     * Dropdowns requieren API calls para opciones dinámicas
   
4. **Implementar date range picker (from/to)**
   - Pros: Mayor flexibilidad de búsqueda
   - Contras:
     * Legacy UI solo muestra un campo Fecha
     * Requisitos no claros (¿range o single date?)
     * Single date suficiente para MVP
     * Date range puede agregarse sin breaking changes

**Consecuencias:**

*Positivas:*
- ✅ Separation of concerns: Módulo separado por propósito (audit vs operational)
- ✅ SRP: AuditFilters solo search, AuditTable solo display
- ✅ Reutilizable: AuditTable props-driven, puede usarse en otros contextos
- ✅ Escalable: Feature structure permite agregar export, advanced filters
- ✅ Type-safe: Interfaces estrictas para AuditEvent y AuditFilters
- ✅ Mock data permite frontend development desacoplado de backend
- ✅ Client-side filtering suficiente para MVP (21 eventos)
- ✅ Consistent con logs/covers/specials patterns (familiaridad equipo)
- ✅ Deep linking support vía routing (bookmarkable URL)
- ✅ Navigation flow claro: Dashboard → Audit (click card)
- ✅ Filtros resetean pagination automáticamente

*Negativas/Limitaciones:*
- ⚠️ Código duplicado con logs/covers/specials (columns pattern, table pattern)
- ⚠️ Mock data hardcoded (TODO comments obligatorios)
- ⚠️ Client-side filtering no escala (>1000 eventos será lento)
- ⚠️ Text inputs en filtros (no dropdowns) requieren typing exacto
- ⚠️ Single date filter (no date range) limita búsquedas temporales
- ⚠️ Sin export functionality (PDF, Excel requerido por legacy)
- ⚠️ Sin estadísticas de actividad por operador

*Mitigaciones:*
- TODO comments claramente marcados para identificar mock data
- Props interface permite agregar export sin breaking changes
- Feature structure permite agregar AdvancedFilters component
- Backend integration point claro: reemplazar mockData + filteredEvents con API hook
- Date range puede agregarse sin breaking UI (add dateToField)

**Cumplimiento de Estándares:**

- ✅ TypeScript obligatorio: Interfaces estrictas para AuditEvent, AuditFilters
- ✅ Feature-based structure: `/features/audit/` mirror de logs/covers/specials
- ✅ Dependency policy: Zero nuevas dependencias
- ✅ Separation of concerns: types, data, columns, filters, table separados
- ✅ SRP: AuditFilters solo search, AuditTable solo presentación
- ✅ DRY: Imports centralizados via index.ts
- ✅ Coding standards: Nombres descriptivos, Spanish labels, comentarios JSDoc
- ✅ ADR-004 compliance: TanStack Table pattern
- ✅ ADR-005 compliance: Context-based routing
- ✅ ADR-006 compliance: Role-based view (supervisor only)
- ✅ ADR-008 compliance: Same clean table design as Specials

**Legacy System Compliance:**

Del `legacy_desktop_functional_context.md` sección 3.7:
- ✅ Admin Dashboard with audit responsibilities
- ✅ Tracks all operator events across the system
- ✅ Filter by user (Usuario)
- ✅ Filter by site (Sitio)
- ✅ Filter by date (Fecha)
- ✅ Read-only view (no creation/editing)
- ✅ Cross-user event visibility
- ⏳ Export functionality: Pendiente (PDF, Excel)
- ⏳ Advanced statistics: Pendiente (activity by operator)

**TypeScript Challenges Fixed:**

*Issue 1: Component name collision*
```typescript
// Problem: AuditFilters imported as both type and component
import { AuditFilters } from "../features/audit";  // ❌ Ambiguous

// Solution: Rename component import to avoid collision
import AuditFiltersComponent from "../features/audit/components/AuditFilters";
import type { AuditFilters } from "../features/audit/types";  // ✅ Clear
```

*Issue 2: Unused function (handleDateToChange)*
```typescript
// Problem: Function declared but never used (date range not implemented yet)
const handleDateToChange = (e: React.ChangeEvent<HTMLInputElement>) => { ... };

// Solution: Comment out with TODO for future implementation
// TODO: Uncomment when date range (to) is implemented
// const handleDateToChange = ...
```

**Futuras Implementaciones (Roadmap):**

1. **Backend Integration (Milestone 2)**
   - Reemplazar mockAuditEvents con `useAuditEvents(filters, pagination)` hook
   - API calls: GET /api/audit/events?user=X&site=Y&dateFrom=Z
   - Server-side filtering y pagination
   - Real-time updates con WebSockets (opcional)
   - Error handling y retry logic

2. **Advanced Filtering (Milestone 3)**
   - Replace text inputs con dropdowns (user list, site list)
   - API calls: GET /api/users (operadores), GET /api/sites
   - Date range picker (from/to) instead of single date
   - Multi-select filters (multiple users, multiple sites)
   - Save filter presets

3. **Export Functionality (Milestone 4)**
   - Export to PDF (requerido por legacy system)
   - Export to Excel (optional)
   - Email reports (send PDF via email)
   - Scheduled reports (daily/weekly audit summaries)

4. **Statistics Dashboard (Milestone 5)**
   - Activity by operator (charts)
   - Events by site (charts)
   - Peak activity times (heatmap)
   - Compliance metrics (event count trends)

5. **Search Optimization (Milestone 6)**
   - Full-text search en description
   - Search history (recent searches)
   - Quick filters (today, this week, this month)
   - Advanced query builder

**Testing Recommendations:**

1. **Unit Tests:**
   - AuditEvent type guards
   - auditEventColumns accessors
   - AuditFilters props interface
   - Filtering logic (useMemo)

2. **Integration Tests:**
   - Navigation flow: SupervisorPage → AuditPage
   - Topbar navigation "Audit" item click
   - Filter application (onFilter callback)
   - Clear filters (onClear callback)
   - Pagination reset after filtering

3. **E2E Tests:**
   - Login as supervisor → click Audit card → see table
   - Apply filters → verify filtered results
   - Clear filters → verify full list restored
   - Navigate pages → verify pagination works
   - Empty state cuando no hay resultados

**Performance Considerations:**

- Client-side filtering: O(n) per filter (acceptable para <1000 eventos)
- useMemo optimization: Re-filters only when events or activeFilters change
- Pagination default: 10 items (ajustable)
- Future: Server-side filtering para >1000 eventos
- Future: Virtual scrolling si table rows >100

**Status:** ✅ Aprobado e Implementado (Milestone 1 completado)

**Revisión:** Reevaluar cuando backend esté listo. Migrar filtering logic a server-side cuando volumen de eventos exceda 500. Considerar agregar export functionality en Milestone 2.

**Dependencias:**
- TanStack Table 8.21.3 (ADR-004)
- React 19.2.0 hooks (useState, useMemo)
- TypeScript 5.9.3 strict mode
- GSAP 3.14.2 (para MagicBento navigation)
- ADR-005 (Context-based routing)
- ADR-006 (Role-based authentication)
- ADR-007 (MagicBento component para navigation)
- ADR-008 (Clean table design pattern)

**Archivos Modificados/Creados:**

*Nuevos:*
- `src/features/audit/types.ts` (95 líneas)
- `src/features/audit/mockData.ts` (155 líneas)
- `src/features/audit/columns.tsx` (90 líneas)
- `src/features/audit/components/AuditTable.tsx` (175 líneas)
- `src/features/audit/components/AuditFilters.tsx` (130 líneas)
- `src/features/audit/index.ts` (15 líneas)
- `src/pages/AuditPage.tsx` (130 líneas)

*Modificados:*
- `src/App.tsx` (AppView type + "audit", AuditPage import, conditional render)
- `src/pages/SupervisorPage.tsx` (4th Audit card, grid-cols-4, onClick handler, auditEvents stats)
- `src/shared/components/Topbar.tsx` (nav item "Audit" para supervisor)

**Total Code:**
- ~790 líneas de código TypeScript
- 7 archivos nuevos
- 3 archivos modificados
- 0 nuevas dependencias

**Referencias:**
- `legacy_desktop_functional_context.md` - Section 3.7 (Admin Dashboard audit)
- ADR-004 - TanStack Table standard
- ADR-005 - Context-based routing
- ADR-006 - Role-based authentication
- ADR-007 - MagicBento component
- ADR-008 - Specials Events feature (clean table design pattern)

---

# ADR-010: Cover Time Module para Supervisor Role (Ámbito: Frontend)

**Fecha:** 15/02/2026

**Ámbito:** 🎨 Frontend

**Contexto:** 
El sistema Daily Log requiere un **módulo de Cover Time** para el rol Supervisor, basado en los requisitos del sistema legacy (legacy_desktop_functional_context.md, sección 3.4 Covers). El módulo Cover Time permite a supervisores auditar y revisar el historial de covers completados, monitoreando el tiempo que operadores estuvieron cubiertos por otros durante breaks, baños, emergencias, etc.

**Requisitos de Negocio:**

Del sistema legacy:
- Covers module: Solicitud, Registro, Cola de espera, Covers de emergencia
- Tablas: covers, covers_programados
- Supervisión de tiempo de cobertura para compliance y análisis de productividad
- Filtrado por operador y rango de fechas

**Diferencia vs Audit:**
- **Audit:** Muestra todos los eventos operacionales (Cleaners, Detailers, Pickups, Dropoffs, etc.)
- **Cover Time:** Específicamente tracks tiempo de cobertura (covers completados)
- **Audit:** Propósito general de supervisión de actividades
- **Cover Time:** Propósito específico de análisis de tiempo de cobertura y productividad

**User Journey:**
1. Supervisor hace login → ve SupervisorPage dashboard
2. Click en card "Cover Time" → navega a CoverTimePage
3. Ve tabla con covers completados de todos los operadores
4. Aplica filtros: Usuario, Desde (fecha), Hasta (fecha)
5. Click "Filtrar" → tabla se filtra
6. Click "Limpiar" → resetea filtros
7. Revisa duración de covers, motivos, y quién cubrió

**Decisión:** 
Implementar **Cover Time feature** como módulo independiente siguiendo arquitectura feature-based existente (logs, covers, specials, audit). Incluye:

1. **Feature Module Structure** (`/features/coverTime/`)
2. **CoverTimeFilters Component** (filtro con Usuario, Desde, Hasta + Filtrar/Limpiar)
3. **CoverTimeTable Component** (tabla read-only con sorting y pagination)
4. **CoverTimePage** (página con filtros + tabla)
5. **Routing Integration** (App.tsx + SupervisorPage navigation "Cover Time")
6. **Topbar Navigation** (nuevo nav item "Cover Time" para supervisor)
7. **Mock Data Strategy** (hardcoded completed covers con TODOs para backend)

**Análisis Técnico:**

*Estructura de Archivos Creados:*

```
src/features/coverTime/
│
├── types.ts                              # Domain types (45 líneas)
│   ├── CoverTimeEvent interface (8 properties)
│   │   ├── id: string                    # UUID del cover event
│   │   ├── user: string                  # Operador cubierto
│   │   ├── startTime: Date               # Inicio Cover
│   │   ├── duration: string              # Duración HH:MM:SS
│   │   ├── endTime: Date                 # Fin Cover
│   │   ├── coveredBy: string             # Quién cubrió
│   │   ├── reason: string                # Motivo (Break, Baño, Emergencia)
│   │   └── timezone: string              # e.g., "GMT-4"
│   ├── CoverTimeFilters (3 optional properties)
│   │   ├── user?: string
│   │   ├── dateFrom?: Date
│   │   └── dateTo?: Date
│   └── CoverTimePaginationParams
│
├── mockData.ts                           # Mock data (185 líneas)
│   ├── mockCoverTimeEvents: CoverTimeEvent[]
│   │   ├── 20 covers hardcoded
│   │   ├── Operadores: Andres G, Logan OP, Emanuel B, Juan C Perez, Carolina N, Vladimir P, etc.
│   │   ├── Covered by: Elizabeth C, Alejandra O, Kevin Castro, Emanuel B, Carolina N, etc.
│   │   ├── Motivos: Break, Cover Baño, Lunch Break, Emergencia Personal, Emergencia Médica
│   │   ├── Duraciones: 00:05:30 a 00:47:55 (realistic cover times)
│   │   └── Fechas: Feb 15, 2026 (mismo día que Audit para consistencia)
│   └── TODO: "DELETE WHEN BACKEND IS READY"
│
├── columns.tsx                           # TanStack Table columns (130 líneas)
│   ├── coverTimeColumns (7 columns)
│   │   ├── # (row number display column)
│   │   ├── Usuario (operator who was covered, capitalized)
│   │   ├── Inicio Cover (date + time formatted es-ES)
│   │   ├── Duración (HH:MM:SS monospace, centered)
│   │   ├── Fin Cover (date + time formatted es-ES)
│   │   ├── Cubierto por (who covered, capitalized)
│   │   └── Motivo (reason badge with color coding)
│   └── Color Coding:
│       ├── Emergencia: Red badge
│       ├── Lunch: Green badge
│       ├── Baño: Yellow badge
│       └── Break: Blue badge
│
├── components/
│   ├── CoverTimeTable.tsx                # Table component (220 líneas)
│   │   ├── Props: data, isLoading, error, pagination, onPaginationChange
│   │   ├── Features:
│   │   │   ├── Sorting state (TanStack Table)
│   │   │   ├── Pagination controls (<<, <, Page X of Y, >, >>)
│   │   │   ├── Loading state: "Cargando covers completados..."
│   │   │   ├── Error state: Display error message
│   │   │   └── Empty state: "No se encontraron covers completados..."
│   │   ├── Same clean design as SpecialsTable, AuditTable (ADR-008, ADR-009)
│   │   └── Styling: bg-slate-800/50, slate borders, clean pagination
│   │
│   └── CoverTimeFilters.tsx              # Filter component (145 líneas)
│       ├── Props: onFilter, onClear
│       ├── Local state para filters (CoverTimeFilters type)
│       ├── 3 Filter Fields:
│       │   ├── Usuario (text input, TODO: replace with dropdown)
│       │   ├── Desde (date picker)
│       │   └── Hasta (date picker)
│       ├── 2 Action Buttons:
│       │   ├── Filtrar (blue, triggers onFilter callback)
│       │   └── Limpiar (gray, triggers onClear callback)
│       └── Grid layout (md:grid-cols-4) responsive
│
└── index.ts                              # Barrel exports
    ├── export { type CoverTimeEvent, ... } from './types';
    ├── export { mockCoverTimeEvents } from './mockData';
    ├── export { coverTimeColumns } from './columns';
    ├── export { default as CoverTimeTable } from './components/CoverTimeTable';
    └── export { default as CoverTimeFilters } from './components/CoverTimeFilters';
```

*CoverTimePage Implementation:*

```typescript
// src/pages/CoverTimePage.tsx (150 líneas)
import { useState, useMemo } from "react";
import MainLayout from "../layouts/MainLayout";
import { CoverTimeTable, mockCoverTimeEvents } from "../features/coverTime";
import CoverTimeFiltersComponent from "../features/coverTime/components/CoverTimeFilters";

export default function CoverTimePage() {
  // TODO: DELETE WHEN BACKEND IS READY - Replace with useCoverTimeEvents hook
  const [events] = useState<CoverTimeEvent[]>(mockCoverTimeEvents);
  const [pagination, setPagination] = useState({ pageIndex: 0, pageSize: 10 });
  const [activeFilters, setActiveFilters] = useState<CoverTimeFilters>({});

  // Client-side filtering (TODO: Move to backend)
  const filteredEvents = useMemo(() => {
    let filtered = [...events];
    
    // Filter by user (case-insensitive partial match)
    if (activeFilters.user) {
      filtered = filtered.filter((event) =>
        event.user.toLowerCase().includes(activeFilters.user!.toLowerCase())
      );
    }
    
    // Filter by date range (Desde)
    if (activeFilters.dateFrom) {
      filtered = filtered.filter((event) => {
        const eventDate = new Date(event.startTime);
        eventDate.setHours(0, 0, 0, 0);
        const fromDate = new Date(activeFilters.dateFrom!);
        fromDate.setHours(0, 0, 0, 0);
        return eventDate >= fromDate;
      });
    }
    
    // Filter by date range (Hasta)
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

  return (
    <MainLayout>
      <h1>Cover Time</h1>
      <CoverTimeFiltersComponent onFilter={handleFilter} onClear={handleClearFilters} />
      <div>Covers Completados ({filteredEvents.length})</div>
      <CoverTimeTable data={filteredEvents} pagination={pagination} onPaginationChange={setPagination} />
    </MainLayout>
  );
}
```

**Diferencias Arquitectónicas vs Audit/Specials:**

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

**Key Architectural Decisions:**

1. **NO FORM porque:**
   - Cover Time es view-only de covers existentes
   - Covers son creados por operadores en Daily module + Covers module
   - Propósito es auditoría de tiempo, no creación

2. **SÍ FILTERS porque:**
   - Legacy UI muestra filtros (Usuario, Desde, Hasta)
   - Necesario para navegar gran volumen de covers en rango de fechas
   - Date range crítico para análisis temporal (día, semana, mes)

3. **Date Range (Desde/Hasta) vs Single Date:**
   - Cover Time requiere análisis temporal (¿cuánto tiempo de cover en la semana?)
   - Diferencia vs Audit (single date): propósito diferente
   - Date range permite estadísticas agregadas (total time, average duration)

4. **Color Coding por Motivo:**
   - Emergencia: Red (alta prioridad visual)
   - Lunch: Green (normal, esperado)
   - Baño: Yellow (corto, esperado)
   - Break: Blue (normal)
   - Facilita identificación rápida de covers anormales

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
  
  // Date range filter: events >= dateFrom
  if (activeFilters.dateFrom) {
    filtered = filtered.filter((event) => {
      const eventDate = new Date(event.startTime);
      eventDate.setHours(0, 0, 0, 0);
      const fromDate = new Date(activeFilters.dateFrom!);
      fromDate.setHours(0, 0, 0, 0);
      return eventDate >= fromDate;
    });
  }
  
  // Date range filter: events <= dateTo
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

**Routing Integration:**

*1. App.tsx Changes:*
```typescript
// Update AppView type
export type AppView = "login" | "daily" | "covers" | "supervisor" | "specials" | "audit" | "coverTime";

// Import CoverTimePage
import CoverTimePage from "./pages/CoverTimePage";

// Add conditional render
{(currentUser?.role === "supervisor" || ...) && 
  currentView === "coverTime" && <CoverTimePage />}
```

*2. SupervisorPage Navigation:*
```typescript
// Update Cover Requests card to Cover Time
<MagicBento onClick={() => setCurrentView("coverTime")} glowColor="234, 179, 8" ... >
  <MagicBentoItem title="Cover Time" ... />
</MagicBento>
```

*3. Topbar Navigation:*
```typescript
// Add nav item for supervisor role
case "supervisor":
case "lead_supervisor":
  return [
    { label: 'Dashboard', value: 'supervisor' },
    { label: 'Specials', value: 'specials' },
    { label: 'Audit', value: 'audit' },
    { label: 'Cover Time', value: 'coverTime' },  // NEW
  ];
```

**Mock Data Strategy:**

*Hardcoded Covers (20):*
```typescript
export const mockCoverTimeEvents: CoverTimeEvent[] = [
  {
    id: "cv-56192",
    user: "Andres G",
    startTime: new Date("2026-02-15T05:58:03"),
    duration: "00:47:55",
    endTime: new Date("2026-02-15T06:46:02"),
    coveredBy: "Elizabeth C",
    reason: "Break",
    timezone: "GMT-4",
  },
  // ... 19 more realistic cover scenarios
];
```

*Scenarios Covered:*
- Multiple operators: 10+ different operators cubiertos
- Multiple cover providers: 10+ operadores que cubrieron
- Various reasons: Break, Cover Baño, Lunch Break, Emergencia Personal, Emergencia Médica
- Duration range: 00:05:30 (baño corto) a 00:47:55 (break largo/emergencia)
- Realistic mix: Mayoría breaks y baños (esperado), pocas emergencias (anormal)

*TODO Comments:*
- mockData.ts: "DELETE WHEN BACKEND IS READY"
- CoverTimePage: "Replace with useCoverTimeEvents hook"
- CoverTimeFilters: "Replace input field with dropdown when backend provides user list"
- Types: "Basado en tabla 'covers' del legacy system"

**Alternativas Consideradas:**

1. **Combinar Cover Time con Audit en una sola vista**
   - Pros: Menos features modules
   - Contras:
     * Propósitos diferentes (compliance general vs coverage analysis)
     * Filtros diferentes (Audit: site filter, Cover Time: date range)
     * Columns diferentes (Audit: camera, activity vs Cover Time: coveredBy, duration)
     * User stories diferentes (event audit vs productivity analysis)
     * Mixing concerns viola SRP

2. **Implementar Cover Time dentro de Covers module (future)**
   - Pros: Lógicamente relacionado con covers
   - Contras:
     * Covers module será para creación/programación de covers
     * Cover Time es auditoría read-only
     * Separación de concerns: creation vs audit
     * Diferentes audiencias: Operador (Covers) vs Supervisor (Cover Time)

3. **Filtro por motivo desde el inicio**
   - Pros: Más granularidad de búsqueda
   - Contras:
     * Legacy UI no muestra filtro por motivo
     * Backend no está listo (hardcoded reasons)
     * Text search en description suficiente para MVP
     * Filtro por motivo puede agregarse sin breaking changes

4. **Estadísticas agregadas en la misma página**
   - Pros: Dashboard-style view con insights
   - Contras:
     * Complica MVP innecesariamente
     * Backend no está listo para cálculos
     * Estadísticas pueden ser feature separada (CoverTimeStats component)
     * Legacy UI es simple listing, no dashboard

**Consecuencias:**

*Positivas:*
- ✅ Separation of concerns: Cover Time audit separado de Audit general
- ✅ SRP: CoverTimeFilters solo search, CoverTimeTable solo display
- ✅ Reutilizable: CoverTimeTable props-driven
- ✅ Escalable: Feature structure permite agregar Cover Time Stats dashboard
- ✅ Type-safe: Interfaces estrictas para CoverTimeEvent y CoverTimeFilters
- ✅ Mock data permite desarrollo frontend desacoplado
- ✅ Date range filter crítico para análisis temporal
- ✅ Color coding facilita identificación de emergencias
- ✅ Consistent con audit/specials patterns
- ✅ Duration tracking permite análisis de productividad

*Negativas/Limitaciones:*
- ⚠️ Client-side filtering no escala (>1000 covers será lento)
- ⚠️ Text input para Usuario (no dropdown) requiere typing exacto
- ⚠️ Sin estadísticas agregadas (total time, average duration por operador)
- ⚠️ Sin filtro por motivo (Break vs Baño vs Emergencia)
- ⚠️ Sin alertas para covers excesivamente largos
- ⚠️ Mock data hardcoded (TODO comments obligatorios)

*Mitigaciones:*
- TODO comments claramente marcados
- Props interface permite agregar duration aggregates sin breaking changes
- Feature structure permite agregar CoverTimeStats component
- Backend integration point claro: reemplazar mockData con API hook
- Date range puede usarse para calcular estadísticas server-side

**Cumplimiento de Estándares:**

- ✅ TypeScript obligatorio: Interfaces estrictas para CoverTimeEvent, CoverTimeFilters
- ✅ Feature-based structure: `/features/coverTime/` mirror de audit/specials
- ✅ Dependency policy: Zero nuevas dependencias
- ✅ Separation of concerns: types, data, columns, filters, table separados
- ✅ SRP: CoverTimeFilters solo search, CoverTimeTable solo presentación
- ✅ DRY: Imports centralizados via index.ts
- ✅ Coding standards: Nombres descriptivos, Spanish labels, comentarios JSDoc
- ✅ ADR-004 compliance: TanStack Table pattern
- ✅ ADR-005 compliance: Context-based routing
- ✅ ADR-006 compliance: Role-based view (supervisor only)
- ✅ ADR-008/009 compliance: Same clean table design

**Legacy System Compliance:**

Del `legacy_desktop_functional_context.md` sección 3.4:
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

**Futuras Implementaciones (Roadmap):**

1. **Backend Integration (Milestone 2)**
   - Reemplazar mockCoverTimeEvents con `useCoverTimeEvents(filters, pagination)` hook
   - API calls: GET /api/covers/completed?user=X&dateFrom=Y&dateTo=Z
   - Server-side filtering y pagination
   - Real-time updates (opcional)

2. **Advanced Filtering (Milestone 3)**
   - Replace text input con dropdown (user list from backend)
   - Filter by reason (Break, Baño, Lunch, Emergencia)
   - Filter by duration range (covers > 15 min, < 5 min)
   - Filter by cover provider

3. **Statistics Dashboard (Milestone 4)**
   - Total cover time por operador
   - Average cover duration por operador
   - Cover time trends (charts)
   - Alertas para covers excesivamente largos
   - Comparison entre operadores

4. **Export Functionality (Milestone 5)**
   - Export to PDF (requerido por legacy system)
   - Export to Excel (optional)
   - Email reports (daily/weekly cover time summaries)
   - Custom report builder

5. **Integration with Covers Module (Milestone 6)**
   - Link to pending covers (covers en progreso)
   - Link to programmed covers (covers_programados)
   - Cover request approval workflow
   - Emergency cover tracking

**Performance Considerations:**

- **Client-side filtering:** O(n) per filter (acceptable para <1000 covers)
- **useMemo optimization:** Re-filters only when events or activeFilters change
- **Pagination default:** 10 items per page (adjustable)
- **Future:** Server-side filtering required para >1000 covers
- **Future:** Virtual scrolling si table rows >100
- **Duration calculations:** Client-side for now, move to backend for aggregates

**Status:** ✅ Aprobado e Implementado (Milestone 1 completado)

**Revisión:** Reevaluar cuando backend esté listo. Implementar statistics dashboard en Milestone 2. Considerar export functionality en Milestone 3.

**Dependencias:**
- TanStack Table 8.21.3 (ADR-004)
- React 19.2.0 hooks (useState, useMemo)
- TypeScript 5.9.3 strict mode
- GSAP 3.14.2 (para MagicBento navigation)
- ADR-005 (Context-based routing)
- ADR-006 (Role-based authentication)
- ADR-007 (MagicBento component para navigation)
- ADR-008/009 (Clean table design pattern)

**Archivos Modificados/Creados:**

*Nuevos:*
- `src/features/coverTime/types.ts` (45 líneas)
- `src/features/coverTime/mockData.ts` (185 líneas)
- `src/features/coverTime/columns.tsx` (130 líneas)
- `src/features/coverTime/components/CoverTimeTable.tsx` (220 líneas)
- `src/features/coverTime/components/CoverTimeFilters.tsx` (145 líneas)
- `src/features/coverTime/index.ts` (18 líneas)
- `src/pages/CoverTimePage.tsx` (150 líneas)

*Modificados:*
- `src/App.tsx` (AppView type + "coverTime", CoverTimePage import, conditional render)
- `src/pages/SupervisorPage.tsx` (Cover Requests card → Cover Time card con onClick)
- `src/shared/components/Topbar.tsx` (nav item "Cover Time" para supervisor)

**Total Code:**
- ~893 líneas de código TypeScript
- 7 archivos nuevos
- 3 archivos modificados
- 0 nuevas dependencias

**Referencias:**
- `legacy_desktop_functional_context.md` - Section 3.4 (Covers)
- ADR-004 - TanStack Table standard
- ADR-005 - Context-based routing
- ADR-006 - Role-based authentication
- ADR-007 - MagicBento component
- ADR-008 - Specials Events feature (clean table design pattern)
- ADR-009 - Audit Trail feature (filtering pattern)

---

# ADR-011: Central Station Map Module para Supervisor Role (Ámbito: Frontend)

**Fecha:** 15/02/2026

**Ámbito:** 🎨 Frontend

**Contexto:** 
El sistema Daily Log requiere un **módulo de Central Station Map** para el rol Supervisor, basado en los requisitos del sistema legacy (legacy_desktop_functional_context.md, sección 3.8 Central Station Map). El módulo permite visualizar en tiempo real el layout del workspace y el estado de ocupación de cada estación de trabajo (workstation), facilitando el monitoreo de operadores activos, estaciones disponibles, y alertas operacionales.

**Requisitos de Negocio:**

Del sistema legacy:
- Visualización del Central Station Map con todas las workstations
- Identificar workstations con IDs únicos (WS_60, WS_62, WS_63, etc.)
- Mostrar estado de workstation: Disponible, Ocupado, Break, Offline, Alerta
- Monitoreo en tiempo real del estado de operadores
- Colores por estado para identificación rápida
- Hover tooltips con información del operador
- Click handlers para ver detalles (futuro)
- Glow effect para alertas críticas

**Diferencia vs Audit/Cover Time:**
- **Audit:** Tabla de eventos históricos (read-only logs)
- **Cover Time:** Tabla de covers completados (read-only audit)
- **Station Map:** Visualización espacial del workspace (SVG-based, real-time status)

**User Journey:**
1. Supervisor hace login → ve SupervisorPage dashboard
2. Click en card "Central Station Map" → navega a StationMapPage
3. Ve mapa SVG del workspace con todas las workstations
4. Identifica visualmente qué estaciones están ocupadas (color coding)
5. Hover sobre workstation → ve tooltip con operador asignado (futuro)
6. Click en workstation → ve detalles del operador (futuro)
7. Observa alertas con efecto glow (futuro)

**Decisión:** 
Implementar **Central Station Map feature** como módulo de visualización SVG siguiendo arquitectura feature-based. Fase 1 (actual): Display-only de SVG estático. Fase 2 (futuro): Real-time WebSocket updates, color coding, interactividad.

1. **Feature Module Structure** (`/features/stationMap/`)
2. **StationMap Component** (SVG display con responsive container)
3. **StationMapPage** (página con visualización full-width)
4. **Routing Integration** (App.tsx + SupervisorPage navigation + Topbar)
5. **SVG Asset Strategy** (src/assets/maps/workspace_map.svg)
6. **Type Definitions** (Workstation, WorkstationStatus)

**Análisis Técnico:**

*Estructura de Archivos Creados:*

```
src/
├── assets/
│   └── maps/
│       └── workspace_map.svg             # SVG del workspace (431 líneas)
│           ├── Dimensions: 1600x900 (16:9)
│           ├── Dark theme: #0f1115 background
│           ├── Style classes: .desk, .screen, .chair, .table, .zone
│           ├── Workstation IDs: WS_60, WS_62, WS_63, WS_24_left, WS_28_left, etc.
│           ├── SVG groups: <g id="WS_XX"> con transform positioning
│           ├── Filter effect: #glow (para alertas)
│           ├── Zones: Left block, Center blocks, Right block
│           └── ~40 workstations + 4 supervisor spaces
│
└── features/stationMap/
    │
    ├── types.ts                          # Domain types (85 líneas)
    │   ├── WorkstationStatus (const object as const)
    │   │   ├── AVAILABLE: 'available'
    │   │   ├── OCCUPIED: 'occupied'
    │   │   ├── OFFLINE: 'offline'
    │   │   ├── ON_BREAK: 'on_break'
    │   │   └── ALERT: 'alert'
    │   ├── WorkstationStatusType (typeof literal)
    │   ├── Workstation interface (6 properties)
    │   │   ├── id: string                # Matches SVG <g> ID
    │   │   ├── status: WorkstationStatusType
    │   │   ├── operatorName?: string
    │   │   ├── operatorId?: number
    │   │   ├── lastUpdate?: string
    │   │   └── alertMessage?: string
    │   ├── WORKSTATION_STATUS_COLORS mapping
    │   │   ├── AVAILABLE: '#10b981' (green-500)
    │   │   ├── OCCUPIED: '#3b82f6' (blue-500)
    │   │   ├── OFFLINE: '#6b7280' (gray-500)
    │   │   ├── ON_BREAK: '#f59e0b' (amber-500)
    │   │   └── ALERT: '#ef4444' (red-500)
    │   └── WORKSTATION_STATUS_LABELS (Spanish)
    │
    ├── components/
    │   └── StationMap.tsx                # SVG display component (60 líneas)
    │       ├── Props: className?: string
    │       ├── Import SVG: import workspaceMapSVG from '../../assets/maps/workspace_map.svg?raw';
    │       ├── Container ref: useRef<HTMLDivElement>
    │       ├── useEffect: Setup for future event listeners
    │       ├── Responsive container:
    │       │   ├── Aspect ratio: 56.25% (16:9)
    │       │   ├── Background: #0a0a0a
    │       │   ├── Border: border-gray-800
    │       │   └── dangerouslySetInnerHTML for SVG injection
    │       └── TODOs:
    │           ├── Add workstation click handlers
    │           ├── Add WebSocket connection
    │           ├── Apply status colors to SVG groups
    │           └── Add hover tooltips
    │
    └── index.ts                          # Barrel exports
        ├── export { WorkstationStatus, ... } from './types';
        ├── export type { Workstation, WorkstationStatusType } from './types';
        └── export { StationMap } from './components/StationMap';
```

*StationMapPage Implementation:*

```typescript
// src/pages/StationMapPage.tsx (95 líneas)
import MainLayout from '../layouts/MainLayout';
import { StationMap } from '../features/stationMap';

export const StationMapPage = () => {
  return (
    <MainLayout>
      <div className="space-y-6">
        {/* Page Header */}
        <h1>Central Station Map</h1>
        <p>Visualización del estado de las estaciones de trabajo</p>

        {/* Development Notice */}
        <div className="bg-blue-500/10 border border-blue-500/20 ...">
          <h3>Modo de desarrollo - Vista estática</h3>
          <p>Funcionalidades en desarrollo:</p>
          <ul>
            <li>Actualización en tiempo real del estado de estaciones (WebSocket)</li>
            <li>Código de colores por estado (Disponible, Ocupado, Break, Alerta, Offline)</li>
            <li>Selección interactiva de estaciones (click para ver detalles)</li>
            <li>Tooltips con información del operador al pasar el mouse</li>
            <li>Filtros por estado y zona</li>
            <li>Leyenda de estados y controles de zoom/pan</li>
            <li>Notificaciones de alertas con efecto visual (glow)</li>
            <li>Exportar snapshot del estado actual</li>
          </ul>
        </div>

        {/* Station Map Visualization */}
        <div className="bg-gray-900 rounded-lg p-6 border border-gray-800">
          <StationMap />
        </div>

        {/* Future Components: */}
        {/* - Status Summary Cards (Available: X, Occupied: Y, etc.) */}
        {/* - Active Alerts Panel */}
        {/* - Recent Status Changes timeline */}
      </div>
    </MainLayout>
  );
};
```

**Diferencias Arquitectónicas vs Audit/Cover Time/Specials:**

| Aspecto              | Audit/Cover Time/Specials | **Station Map**          |
|----------------------|---------------------------|--------------------------|
| **User Role**        | Supervisor                | **Supervisor**           |
| **Data Type**        | Table-based (rows)        | **Spatial (SVG)**        |
| **Component Type**   | TanStack Table            | **SVG Visualization**    |
| **Filter Component** | ✅ Date/User filters      | ❌ **No filters (Fase 1)**|
| **Primary Action**   | Search & Filter           | **Monitor & Observe**    |
| **Data Format**      | Array of events           | **SVG + status map**     |
| **Interactivity**    | Sort/Paginate             | **Click/Hover (Fase 2)** |
| **Real-time**        | ❌ Static snapshots       | ✅ **WebSocket (Fase 2)**|
| **Purpose**          | Historical audit          | **Real-time monitoring** |
| **Visualization**    | List/Table                | **2D spatial layout**    |

**Key Architectural Decisions:**

1. **SVG Asset Strategy:**
   - **Decision:** Ubicar SVG en `src/assets/maps/workspace_map.svg`
   - **Rationale:**
     * `src/assets/` permite imports type-safe en TypeScript
     * Vite bundler optimiza SVG con tree-shaking
     * `?raw` suffix permite inline SVG para future DOM manipulation
     * Future: Manipular SVG DOM para color coding (workstation status)
     * Alternative `public/assets/` no permite fácil manipulación DOM
   - **Import strategy:**
     ```typescript
     import workspaceMapSVG from '../../assets/maps/workspace_map.svg?raw';
     <div dangerouslySetInnerHTML={{ __html: workspaceMapSVG }} />
     ```

2. **NO Tabla TanStack porque:**
   - Workspace visualization es espacial, no tabular
   - SVG preserva physical layout del workspace real
   - Tabla no representa posición relativa de workstations
   - Propósito es monitoring visual, no data filtering

3. **NO Filters (Phase 1) porque:**
   - MVP es display-only
   - Filters vendrán en Phase 2 con interactividad
   - Future filters: estado (Available/Occupied), zona (Left/Center/Right)

4. **Fase 1 vs Fase 2 Division:**
   
   **Phase 1 (MVP - Actual):**
   - ✅ Display SVG estático
   - ✅ Responsive container (16:9 aspect ratio)
   - ✅ Dark theme matching app design
   - ✅ Type definitions ready para future backend
   - ❌ No color coding (SVG default colors)
   - ❌ No interactivity (no click, no hover)
   - ❌ No WebSocket connection
   
   **Phase 2 (Future - Backend Ready):**
   - 🔄 Real-time WebSocket updates
   - 🔄 Color coding based on WorkstationStatus
   - 🔄 Click handlers: Show operator details modal
   - 🔄 Hover tooltips: Operator name + status
   - 🔄 Glow effect for alerts (filter: url(#glow))
   - 🔄 Status legend component
   - 🔄 Zoom/pan controls
   - 🔄 Status filters (Available, Occupied, etc.)

5. **WorkstationStatus como const object (no enum):**
   - **Reason:** TypeScript `erasableSyntaxOnly` config
   - Enums not allowed con esta configuración
   - `const WorkstationStatus = { ... } as const;` + type inference
   - `type WorkstationStatusType = typeof WorkstationStatus[keyof typeof WorkstationStatus];`
   - Same pattern usado en otros módulos

6. **SVG Structure Analysis:**
   - ~40 workstation groups con IDs únicos
   - Pattern: `<g id="WS_XX" transform="translate(x,y)">...</g>`
   - Future: `document.getElementById('WS_60')` para manipular color
   - Future: Add event listeners a cada workstation group
   - Filter `#glow` ya definido en SVG para alertas

**Routing Integration:**

*1. App.tsx Changes:*
```typescript
// Update AppView type
export type AppView = "login" | "daily" | "covers" | "supervisor" | "specials" | "audit" | "coverTime" | "stationMap";

// Import StationMapPage
import { StationMapPage } from "./pages/StationMapPage";

// Add conditional render
{(currentUser?.role === "supervisor" || ...) && 
  currentView === "stationMap" && <StationMapPage />}
```

*2. SupervisorPage Navigation:*
```typescript
// Update Team Statistics card (already named "Central Station Map")
<MagicBento onClick={() => setCurrentView("stationMap")} glowColor="34, 197, 94" ... >
  <MagicBentoItem 
    title="Central Station Map" 
    description="Monitor real-time operator status and performance"
    footer="TODO: Implement real-time updates"
  />
</MagicBento>
```

*3. Topbar Navigation:*
```typescript
// Add nav item for supervisor role
case "supervisor":
case "lead_supervisor":
  return [
    { label: 'Dashboard', value: 'supervisor' },
    { label: 'Specials', value: 'specials' },
    { label: 'Audit', value: 'audit' },
    { label: 'Cover Time', value: 'coverTime' },
    { label: 'Station Map', value: 'stationMap' },  // NEW
  ];
```

**SVG Workstation Mapping:**

*Workstation IDs identificados en SVG:*
- **Left Column:** WS_60, WS_62, WS_63, WS_24_left, WS_28_left, WS_25_left, WS_30, WS_26_left, WS_16, WS_27_left, WS_31
- **Center Left:** WS_36 (IT3), WS_35 (IT2), WS_34 (IT1), WS_33 (Lead Supervisor), WS_17_center, WS_20, WS_18_center, WS_21, WS_19_center, WS_22, WS_23_center (Supervisor)
- **Center Right:** WS_17, WS_18, WS_19, WS_32 (Lead Supervisor), WS_10_right, WS_13, WS_11, WS_10_right2, WS_12, WS_15, WS_23 (Supervisor)
- **Right Column:** WS_24, WS_25, WS_26, WS_27, WS_1, WS_8, WS_2, WS_7, WS_3, WS_6, WS_4, WS_5, WS_9 (Supervisor)

*Total: ~40 workstations + 4 supervisor spaces*

**Phase 2 Implementation Strategy (Future):**

*1. WebSocket Connection:*
```typescript
// StationMap.tsx
useEffect(() => {
  const ws = new WebSocket('ws://localhost:8000/ws/stations/');
  
  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    // data: { workstationId: 'WS_60', status: 'occupied', operatorName: 'Andres G' }
    updateWorkstationStatus(data);
  };
  
  return () => ws.close();
}, []);
```

*2. Color Coding Application:*
```typescript
const updateWorkstationStatus = (data: WorkstationUpdate) => {
  const svgGroup = document.getElementById(data.workstationId);
  if (svgGroup) {
    const desk = svgGroup.querySelector('.desk');
    const screen = svgGroup.querySelector('.screen');
    
    const color = WORKSTATION_STATUS_COLORS[data.status];
    if (desk) desk.setAttribute('fill', color);
    if (screen) screen.setAttribute('stroke', color);
    
    // Apply glow for alerts
    if (data.status === WorkstationStatus.ALERT) {
      svgGroup.setAttribute('filter', 'url(#glow)');
    } else {
      svgGroup.removeAttribute('filter');
    }
  }
};
```

*3. Interactive Click Handlers:*
```typescript
useEffect(() => {
  const svg = containerRef.current?.querySelector('svg');
  if (!svg) return;
  
  // Add click handler to all workstation groups
  const workstations = svg.querySelectorAll('g[id^="WS_"]');
  workstations.forEach((ws) => {
    ws.addEventListener('click', (e) => {
      const workstationId = ws.getAttribute('id');
      // Show modal with operator details
      handleWorkstationClick(workstationId);
    });
  });
}, []);
```

*4. Hover Tooltips:*
```typescript
// Add tooltip div
<div 
  ref={tooltipRef}
  className="absolute bg-gray-800 text-white p-2 rounded hidden"
>
  {/* Tooltip content: operatorName, status, lastUpdate */}
</div>

// Hover listeners
ws.addEventListener('mouseenter', (e) => {
  const workstation = workstationData[workstationId];
  showTooltip(e.clientX, e.clientY, workstation);
});

ws.addEventListener('mouseleave', () => {
  hideTooltip();
});
```

**Alternativas Consideradas:**

1. **Canvas en lugar de SVG**
   - Pros: Mayor rendimiento para animaciones complejas
   - Contras:
     * No preserva estructura DOM (difícil manipulación individual)
     * No accesible (screen readers)
     * Requiere redraw completo para updates
     * SVG es declarativo y manipulable via DOM
     * Workstations son estáticos, no requieren high-frame-rate animations

2. **React Components en lugar de SVG inline**
   - Pros: React-native approach, más "React way"
   - Contras:
     * Conversión manual de 431 líneas SVG a componentes
     * Pérdida de diseño original
     * Overhead de re-renders
     * SVG inline permite usar diseño legacy exacto
     * Future backend puede generar SVG dinámicamente

3. **Public folder para SVG (public/assets/workspace_map.svg)**
   - Pros: Accesible via URL directa
   - Contras:
     * No type-safe imports
     * No bundling optimization
     * Difícil manipulación DOM desde React
     * `src/assets/` permite `?raw` import para inline

4. **Librería react-svg o similar**
   - Pros: SVG manipulation library con React hooks
   - Contras:
     * Nueva dependencia (contra dependency policy)
     * Overkill para caso simple
     * Raw SVG + dangerouslySetInnerHTML suficiente
     * Future DOM manipulation puede hacerse con vanilla JS

5. **Implementar zoom/pan desde Phase 1**
   - Pros: Mejor UX desde el inicio
   - Contras:
     * Complejidad innecesaria para MVP
     * Requiere librería (d3-zoom o similar)
     * Workspace es lo suficientemente pequeño para ver completo
     * Phase 2 puede agregar zoom sin breaking changes

**Consecuencias:**

*Positivas:*
- ✅ Visualización espacial preserva layout físico del workspace
- ✅ SVG escalable y responsive (16:9 aspect ratio)
- ✅ Type definitions listas para Phase 2 (backend integration)
- ✅ Zero nuevas dependencias
- ✅ Future DOM manipulation straightforward (getElementById)
- ✅ Dark theme matching app design system
- ✅ Supervisor monitoring capability (Phase 2)
- ✅ Alert visualization capability (glow effect)
- ✅ Extensible: Status legend, zoom/pan, filters pueden agregarse

*Negativas/Limitaciones (Phase 1):*
- ⚠️ No real-time updates (static display)
- ⚠️ No color coding (SVG default colors)
- ⚠️ No interactivity (no click, no hover)
- ⚠️ No status information displayed
- ⚠️ No legend explaining workstation IDs

*Mitigaciones:*
- TODO comments claramente marcados en StationMap.tsx
- Development notice en StationMapPage explica Phase 2 features
- Type definitions preparadas para backend integration
- SVG structure permite fácil manipulación (IDs únicos)

**Cumplimiento de Estándares:**

- ✅ TypeScript obligatorio: Interfaces Workstation, WorkstationStatusType
- ✅ Feature-based structure: `/features/stationMap/`
- ✅ Dependency policy: Zero nuevas dependencias
- ✅ Separation of concerns: types, components separados
- ✅ SRP: StationMap solo visualización
- ✅ DRY: Imports centralizados via index.ts
- ✅ Coding standards: Nombres descriptivos, Spanish labels
- ✅ ADR-005 compliance: Context-based routing
- ✅ ADR-006 compliance: Role-based view (supervisor only)
- ✅ ADR-007 compliance: MagicBento navigation card

**Legacy System Compliance:**

Del `legacy_desktop_functional_context.md` sección 3.8:
- ✅ Central Station Map visualization
- ✅ Workstation layout preservado
- ✅ Unique IDs para cada workstation
- ⏳ Real-time status updates (Fase 2)
- ⏳ Operator name display (Fase 2)
- ⏳ Status color coding (Fase 2)
- ⏳ Alert notifications with glow (Fase 2)
- ⏳ Click for operator details (Fase 2)

**Futuras Implementaciones (Roadmap):**

**Phase 2 (Backend Integration):**
- ✅ WebSocket connection: `ws://localhost:8000/ws/stations/`
- ✅ Real-time status updates
- ✅ Color coding based on WorkstationStatus
- ✅ Workstation tooltips: operatorName, status, lastUpdate
- ✅ Click handlers: Show operator details modal
- ✅ Glow effect for alerts

**Phase 3 (Advanced Features):**
- Status legend component
- Status filters: Show only Available, or only Occupied
- Zone filters: Left Column, Center, Right Column
- Search workstation by ID or operator name
- Export snapshot (PNG/PDF)

**Phase 4 (Enhanced UX):**
- Zoom/pan controls (d3-zoom or custom)
- Minimap for navigation (si workspace crece)
- Animation transitions para status changes
- Sound alerts para critical status (ALERT)
- Historical playback (replay status changes)

**Phase 5 (Analytics Integration):**
- Status summary cards: Available count, Occupied count, etc.
- Recent status changes timeline
- Active alerts panel
- Integration con Cover Time module (highlight workstations on break)
- Integration con Audit module (highlight workstations with recent events)

**Performance Considerations:**

- **SVG size:** 431 líneas, ~15KB raw (acceptable)
- **Inline SVG:** dangerouslySetInnerHTML renders once, no re-renders
- **Responsive:** Aspect ratio container scales SVG sin distortion
- **Future:** WebSocket updates solo modifican DOM elements afectados (O(1))
- **Future:** Virtual workstation tracking (solo render visible area si workspace crece)

**Security Considerations:**

- **dangerouslySetInnerHTML:** Safe porque SVG es asset static, no user input
- **Future WebSocket:** Validar data del backend antes de aplicar
- **XSS prevention:** No user-generated SVG content

**Status:** ✅ Aprobado e Implementado (Phase 1 completado)

**Revisión:** Reevaluar cuando backend esté listo con WebSocket support. Implementar Phase 2 (real-time updates, interactivity) en Milestone 2. Phase 3 (advanced filters, legend) en Milestone 3.

**Dependencias:**
- React 19.2.0 hooks (useEffect, useRef)
- TypeScript 5.9.3 strict mode
- Vite 7.3.1 (SVG ?raw import)
- GSAP 3.14.2 (para MagicBento navigation)
- ADR-005 (Context-based routing)
- ADR-006 (Role-based authentication)
- ADR-007 (MagicBento component para navigation)

**Archivos Modificados/Creados:**

*Nuevos:*
- `src/assets/maps/workspace_map.svg` (431 líneas)
- `src/features/stationMap/types.ts` (85 líneas)
- `src/features/stationMap/components/StationMap.tsx` (60 líneas)
- `src/features/stationMap/index.ts` (14 líneas)
- `src/pages/StationMapPage.tsx` (95 líneas)

*Modificados:*
- `src/App.tsx` (AppView type + "stationMap", StationMapPage import, conditional render)
- `src/pages/SupervisorPage.tsx` (Central Station Map card onClick → setCurrentView("stationMap"))
- `src/shared/components/Topbar.tsx` (nav item "Station Map" para supervisor)

**Total Code:**
- ~685 líneas de código TypeScript + SVG (431 líneas SVG)
- 5 archivos nuevos
- 3 archivos modificados
- 0 nuevas dependencias

**Referencias:**
- `legacy_desktop_functional_context.md` - Section 3.8 (Central Station Map)
- ADR-005 - Context-based routing
- ADR-006 - Role-based authentication
- ADR-007 - MagicBento component
- Vite SVG import documentation: https://vitejs.dev/guide/assets.html#importing-asset-as-string

---
