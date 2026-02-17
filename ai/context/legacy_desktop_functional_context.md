# LEGACY CONTEXT — DESKTOP APPLICATION (SOURCE FOR MIGRATION)

## 1. Propósito General

Daily Log System (SLC) es un sistema de gestión para estación central de monitoreo de seguridad.

Objetivos principales:
- Registro de turnos
- Registro de eventos operativos
- Gestión de eventos especiales
- Gestión de covers
- Gestión de breaks
- Healthcheck de tickets externos
- Auditoría administrativa
- Visualización en mapa de estaciones

---

# 2. Dominio Funcional

## Roles del Sistema
- Operador
- Supervisor
- Lead Supervisor
- Admin

---

# 3. Módulos Funcionales

## 3.1 Autenticación y Sesión
Responsabilidades:
- Validación contra MySQL
- Gestión de sesión activa
- Asignación de estación
- Liberación de estación en logout

Tablas involucradas:
- sesion
- stations_map

Flujo crítico:
LOGIN → Crear sesión → Asignar estación

---

## 3.2 Daily Events
Responsabilidades:
- Registro desde START SHIFT
- Edición inline
- Auto-save
- Relación con usuario y sitio

Tabla principal:
- Eventos

Restricción de dominio:
Eventos solo visibles desde último START SHIFT

---

## 3.3 Specials Events
Responsabilidades:
- Basado en Eventos
- FK ID_Eventos
- Estados: enviado / pendiente
- Asignación a supervisor
- Ajuste timezone

Tabla:
- specials (FK Eventos)

Regla crítica:
Comparación automática Eventos vs Specials

---

## 3.4 Covers
Responsabilidades:
- Solicitud
- Registro
- Cola de espera
- Covers de emergencia

Tablas:
- covers
- covers_programados

---

## 3.5 Breaks
Responsabilidades:
- Programación
- Validaciones de tiempo

---

## 3.6 Healthcheck
Responsabilidades:
- Integración API externa
- Paginación
- Cache en red

Dependencia externa:
sigdomain01:8080

---

## 3.7 Admin Dashboard
Responsabilidades:
- Estadísticas
- Gestión usuarios
- Auditoría

---

## 3.8 Central Station Map
Responsabilidades:
- Visualización estaciones
- Estado operador en tiempo real

Tabla:
- stations_map

---

# 4. Flujo Principal Operador

LOGIN → Blackboard → DAILY / SPECIALS / COVERS → END SHIFT → LOGOUT

---

# 5. Reglas de Dominio Implícitas Detectadas

- No hay eventos sin sesión activa.
- START SHIFT inicia contexto de eventos.
- END SHIFT cierra ciclo.
- Specials dependen de Eventos.
- Covers requieren aprobación supervisor.
- Logout debe liberar estación.

---

# 6. Riesgos para Migración

- Acoplamiento fuerte entre UI y lógica.
- Posible mezcla de responsabilidades.
- Dependencia directa a MySQL.
- Dependencia externa API healthcheck.
- Lógica de timezone vía regex (riesgo técnico).
