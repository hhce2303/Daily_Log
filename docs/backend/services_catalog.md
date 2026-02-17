# Services Catalog

## Daily Events

### create_daily_event
Responsabilidad:
- Crear evento validando sesión activa.

Entrada:
- user_id
- site_id
- activity
- description

Reglas:
- Debe existir START SHIFT activo.
- Debe estar dentro de sesión activa.

Errores posibles:
- SessionNotActiveError
