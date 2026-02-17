# ARCHITECTURE OVERVIEW

## Estilo Arquitectónico

Modular Monolith  
Layered Architecture  
Service Layer Pattern  
Optimizado para AI-assisted development

---

# 1️⃣ Visión General

El sistema está diseñado como un monolito modular con separación estricta de responsabilidades.

Cada módulo funcional debe ser entendible de forma aislada.

No se permite mezcla de dominio con infraestructura.

---

# 2️⃣ Capas del Sistema

El flujo general es:

┌───────────────────────────────┐
│        Presentation Layer      │
│  (Controllers / API / Views)   │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│        Application Layer       │
│          (Services)            │
│  Lógica de negocio explícita   │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│         Domain Layer           │
│          (Models)              │
│  Reglas de dominio puras       │
└───────────────┬───────────────┘
                │
                ▼
┌───────────────────────────────┐
│      Data Access Layer         │
│        (ORM / DB)              │
└───────────────────────────────┘

---

# 3️⃣ Flujo de Escritura (Write Path)

Controller
    ↓
Service
    ↓
Model
    ↓
Database

Reglas:
- Controllers no contienen lógica.
- Services contienen reglas de negocio.
- Models solo contienen definición de datos y reglas puras.
- Transacciones se manejan en Services.

---

# 4️⃣ Flujo de Lectura (Read Path)

Controller
    ↓
Selector
    ↓
Model
    ↓
Database

Reglas:
- Selectors solo lectura.
- No mutación de estado en Selectors.
- Optimización de queries obligatoria.

---

# 5️⃣ Estructura Modular Esperada

Cada módulo funcional debe seguir esta estructura:

module_name/
│
├── models.py
├── services.py
├── selectors.py
├── controllers.py
└── tests/

---

# 6️⃣ Principios Arquitectónicos

1. Separación estricta de responsabilidades.
2. No lógica en serializers.
3. No acceso directo a DB desde controllers.
4. No dependencias cruzadas entre módulos sin justificación.
5. Servicios pequeños y atómicos.
6. Código entendible por IA y humanos.

---

# 7️⃣ Optimización para IA

Esta arquitectura está diseñada para:

- Minimizar ambigüedad.
- Reducir archivos gigantes.
- Permitir generación modular.
- Facilitar refactor incremental.
- Facilitar auditoría automática.

Cada capa tiene una responsabilidad clara, lo que mejora la capacidad de análisis de modelos de IA.

---

# 8️⃣ Evolución Futura

La arquitectura permite evolucionar hacia:

- Clean Architecture completa
- Hexagonal Architecture
- Microservicios

Sin necesidad de reescritura total.

---

# 9️⃣ Prohibiciones

- No introducir lógica en views.
- No mezclar lectura y escritura.
- No usar patrones mágicos.
- No romper la separación de capas.
